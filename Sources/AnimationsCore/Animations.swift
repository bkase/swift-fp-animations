import CoreGraphics

// todo: change mentions of time to progress
public typealias Progress = CFAbsoluteTime

public struct Animation<A: Semigroup> {
  public let duration: CFAbsoluteTime
  private let _value: (CFAbsoluteTime) -> A

  public init(duration: CFAbsoluteTime, value: @escaping (CFAbsoluteTime) -> A) {
    self.duration = duration
    self._value = value
  }

  public func value(_ t: CFAbsoluteTime) -> A {
    precondition(self.duration > 0, "Can't call zero-duration animations.")
    return self._value(t)
  }

  public var start: A {
    return self._value(0)
  }

  public var end: A {
    return self._value(1)
  }

  /// Converts a pure animation into an effectful animatino.
  public func `do`(_ f: @escaping (A) -> Void) -> Animation<Unit> {
    return .init(duration: self.duration) { t in
      f(self.value(t))
      return Unit.unit
    }
  }

  public func transformTime(_ f: @escaping (CFAbsoluteTime) -> CFAbsoluteTime) -> Animation {
    return .init(duration: self.duration) { t in
      return self.value(f(t))
    }
  }

  /// Transforms the outut of the animation.
  public func map<B>(_ f: @escaping (A) -> B) -> Animation<B> {
    return .init(duration: self.duration) { t in f(self.value(t)) }
  }

  /// Reverses the animation.
  public var reversed: Animation<A> {
    return Animation(duration: self.duration) { t in
      return self.value(1 - t)
    }
  }

  /// Sequences two animations.
  public static func * (lhs: Animation, rhs: Animation) -> Animation {
    let sum = lhs.duration + rhs.duration
    let ratio = lhs.duration / sum

    return Animation(duration: sum) { t in
      (t <= ratio && lhs.duration != 0)
        ? lhs.value(t / ratio)
        : rhs.value((t - ratio) / (1 - ratio))
    }
  }
    
  /// Runs two animations in paralllel and combines the results. If one is longer than the other, the shorter one will stop at it's
  /// last value until the longer one finishes.
  public static func + (lhs: Animation, rhs: Animation) -> Animation {
    let newDuration = max(lhs.duration, rhs.duration)
    
    return .init(duration: newDuration) { t in
      let a1 = lhs.value(min(1, t * newDuration / lhs.duration))
      let a2 = rhs.value(min(1, t * newDuration / rhs.duration))
      return a1 <> a2
    }
  }

  /// An animation of zero duration that does nothing. The `.value()` function of this animation should
  /// never be called. In general, zero duration animations should just be skipped.
  /// A multiplicative identity
  public static var one: Animation {
    return .init(duration: 0) { _ in fatalError() }
  }

  /// Repeats this animation `count` times.
  public func repeating(count: Int) -> Animation {
    let doubleCount = Double(count)
    return Animation(duration: self.duration * doubleCount) { t in
      return self.value((t * doubleCount).truncatingRemainder(dividingBy: 1))
    }
  }

  /// Run this animation and then runs its reverse.
  public var looped: Animation {
    return self * self.reversed
  }

  /// Delays this animation by the amount specified.
  public func delayed(by delay: CFAbsoluteTime) -> Animation {
    return const(value: self.start, duration: delay) * self
  }


  /// Experimental: Chris is a fan of this function, but I don't quite understand it yet. It kinda lets you
  /// chain a new animation onto an existing one by giving the next animation the final value of the
  // previous.
  public func andThen(_ rhs: @escaping (A) -> Animation) -> Animation {
    return self * rhs(self.end)
  }
}

public struct FunctionS<A, S: Semigroup>: Semigroup {
  public let run: (A) -> S
  
  public init(_ run: @escaping (A) -> S) {
    self.run = run
  }
  
  public static func <>(lhs: FunctionS, rhs: FunctionS) -> FunctionS {
    return FunctionS { a in
      lhs.run(a) <> rhs.run(a)
    }
  }
}

public func ap<A, B>(_ f: Animation<FunctionS<A, B>>, _ a: Animation<A>) -> Animation<B> {
  return Animation<B>(duration: max(a.duration, f.duration)) { t in
    f.value(t).run(a.value(t))
  }
}

/// Creates a constant animation that stays at a value for all time.
public func const<A>(value: A, duration: CFAbsoluteTime) -> Animation<A> {
  return Animation(duration: duration, value: { _ in value })
}

// we need conditional conformance here...
extension Animation where A == FloatAverage<CGFloat> {
  /// Binds the animation to an object with a keyPath.
  public func bind<B>(_ obj: B, with keyPath: ReferenceWritableKeyPath<B,   CGFloat>) -> Animation<Unit> {
    return self.do { a in
      obj[keyPath: keyPath] = a.avg
    }
  }
}
