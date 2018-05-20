import CoreGraphics

// todo: change mentions of time to progress
public typealias Progress = CFAbsoluteTime

public enum Animation<A> {
    case cancelled
    case trivial
    case _runnable(duration: CFAbsoluteTime, value: (Progress) -> A)
    
    static func runnable(duration: CFAbsoluteTime, value: @escaping (Progress) -> A) -> Animation<A> {
        precondition(duration > 0)
        return Animation._runnable(duration:duration, value:value)
    }
    
    var duration: CFAbsoluteTime {
        switch self {
        case .cancelled:
            return 0
        case .trivial:
            return 0
        case let ._runnable(duration, _):
            return duration
        }
    }
    
    public func value(_ t: CFAbsoluteTime) -> A? {
        switch self {
        case .cancelled, .trivial:
            return nil
        case let ._runnable(_, value):
            return value(t)
        }
    }
    
    /// A cancelled animation annihalates another when put in sequence.
    /// An additive identity
    public static var zero: Animation {
        return .cancelled
    }
    
    /// An animation of zero duration that does nothing.
    /// A multiplicative identity
    public static var one: Animation {
        return .trivial
    }
    
    public func sequence(_ next: Animation) -> Animation {
        switch (self, next) {
        case (.cancelled, _),
             (_, .cancelled):
            return .cancelled
        case (.trivial, let x),
             (let x, .trivial):
            return x
        case (._runnable(let duration1, let value1), ._runnable(let duration2, let value2)):
            let sum = duration1 + duration2
            let ratio = duration1 / sum
            
            return Animation.runnable(duration: sum) { t in
                (t <= ratio && duration1 != 0)
                    ? value1(t / ratio)
                    : value2((t - ratio) / (1 - ratio))
            }
        }
    }
}

extension Animation: Semiring where A: Semigroup {
    public static func +(lhs: Animation, rhs: Animation) -> Animation {
        switch (lhs, rhs) {
        case (.cancelled, .trivial),
             (.trivial, .cancelled),
             (.trivial, .trivial):
            return .trivial
        case (.cancelled, .cancelled):
            return .cancelled
        case (._runnable(let duration1, let value1), ._runnable(let duration2, let value2)):
            let newDuration = max(duration1, duration2)

            return .runnable(duration: newDuration) { t in
                let a1 = value1(min(1, t * newDuration / duration1))
                let a2 = value2(min(1, t * newDuration / duration2))
                return a1 <> a2
            }
        case (_, ._runnable(let d, let v)),
             (._runnable(let d, let v), _):
            return .runnable(duration:d, value:v)
        }
    }
    /// Sequences two animations.
    public static func * (lhs: Animation, rhs: Animation) -> Animation {
        return lhs.sequence(rhs)
    }
}

extension Animation {
    /// Converts a pure animation into an effectful animatino.
    public func `do`(_ f: @escaping (A) -> ()) -> Animation<Unit> {
        switch self {
        case .trivial:
            return .trivial
        case .cancelled:
            return .cancelled
        case ._runnable(let duration, let value):
            return Animation<Unit>.runnable(duration: duration) { t in
                f(value(t))
                return Unit.unit
            }
        }
    }
    
    public func transformTime(_ f: @escaping (CFAbsoluteTime) -> CFAbsoluteTime) -> Animation {
        switch self {
        case .trivial:
            return .trivial
        case .cancelled:
            return .cancelled
        case ._runnable(let duration, let value):
            return .runnable(duration: duration) { t in
                value(f(t))
            }
        }
    }
    
    /// Transforms the outut of the animation.
    public func map<B>(_ f: @escaping (A) -> B) -> Animation<B> {
        switch self {
        case .trivial:
            return .trivial
        case .cancelled:
            return .cancelled
        case ._runnable(let duration, let value):
            return .runnable(duration: duration) { t in
                f(value(t))
            }
        }
    }
    
    /// Reverses the animation.
    public var reversed: Animation<A> {
        switch self {
        case .trivial:
            return .trivial
        case .cancelled:
            return .cancelled
        case ._runnable(let duration, let value):
            return .runnable(duration: duration) { t in
                return value(1 - t)
            }
        }
    }
    
    /// Repeats this animation `count` times.
    public func repeating(count: Int) -> Animation {
        switch self {
        case .trivial:
            return .trivial
        case .cancelled:
            return .cancelled
        case ._runnable(let duration, let value):
            let doubleCount = Double(count)
            return .runnable(duration: duration * doubleCount) { t in
                return value((t * doubleCount).truncatingRemainder(dividingBy: 1))
            }
        }
    }
    
    /// Run this animation and then runs its reverse.
    public var looped: Animation {
        return self.sequence(self.reversed)
    }
    
    /// Delays this animation by the amount specified.
    public func delayed(by delay: CFAbsoluteTime) -> Animation {
        switch self {
        case .trivial:
            return .trivial
        case .cancelled:
            return .cancelled
        case ._runnable(_, let value):
            if delay == 0 {
                return self
            }
            return const(value: value(0), duration: delay).sequence(self)
        }
    }
}

public func ap<A, B>(_ f: Animation<(A) -> B>, _ a: Animation<A>) -> Animation<B> {
    switch (f, a) {
    case (.cancelled, _),
         (_, .cancelled):
        return .cancelled
    case (.trivial, _),
         (_, .trivial):
        return .trivial
    case (._runnable(let fDuration, let fValue), ._runnable(let aDuration, let aValue)):
        return Animation<B>.runnable(duration: max(aDuration, fDuration)) { t in
            fValue(t)(aValue(t))
        }
    }
}

/// Creates a constant animation that stays at a value for all time.
public func const<A>(value: A, duration: CFAbsoluteTime) -> Animation<A> {
  return Animation.runnable(duration: duration, value: { _ in value })
}

// we need conditional conformance here...
extension Animation where A == CGFloatAverage {
  /// Binds the animation to an object with a keyPath.
  public func bind<B>(_ obj: B, with keyPath: ReferenceWritableKeyPath<B, CGFloat>) -> Animation<Unit> {
    return self.do { a in
      obj[keyPath: keyPath] = a.avg
    }
  }
}

typealias AAtoBBtoAB<A,B> = (Tuple2<A, A>) -> (Tuple2<B, B>) -> Tuple2<A, B>
// recover the tupling operation
infix operator ++: AdditionPrecedence
public func ++<A, B>(lhs: Animation<A>, rhs: Animation<B>) -> Animation<Tuple2<A, B>> {
    let aa = lhs.map{ a in Tuple2<A, A>(a, a) }
    let bb = rhs.map{ b in Tuple2<B, B>(b, b) }
    let f: AAtoBBtoAB<A,B> = { aa in { bb in Tuple2<A, B>(aa.a, bb.b) }
    }
    let af = const(value: f, duration: max(aa.duration, bb.duration))
    return ap(ap(af, aa), bb)
}
