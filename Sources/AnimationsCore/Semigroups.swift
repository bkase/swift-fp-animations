//
//  Average.swift
//  AnimationsPackageDescription
//
//  Created by Brandon Kase on 10/12/17.
//

import Foundation
import CoreGraphics

infix operator <>: AdditionPrecedence

public protocol Semigroup {
  static func <>(lhs: Self, rhs: Self) -> Self
}
// you don't _need_ the monoid instance, but it makes recovering the tuple version of `+` less awkward
public protocol Monoid: Semigroup {
  static var empty: Self { get }
}

public protocol Average {
    associatedtype AverageType
    var avg: AverageType { get }
}
extension Optional: Average where Wrapped: Average {
    public typealias AverageType = Optional<Wrapped.AverageType>
    public var avg: AverageType {
        switch self {
        case .some(let x):
            return x.avg
        case .none:
            return nil
        }
    }
}

public protocol Semiring {
    static var one: Self { get }
    static var zero: Self { get }
    static func *(lhs: Self, rhs: Self) -> Self
    static func +(lhs: Self, rhs: Self) -> Self
}
extension Semiring {
    func mult(_ rhs: Self) -> Self {
        return self * rhs
    }
    func add(_ rhs: Self) -> Self {
        return self + rhs
    }
}

public struct Tuple2<A, B> {
  public let a: A
  public let b: B
  public init(_ a: A, _ b: B) {
    self.a = a
    self.b = b
  }
}
extension Tuple2: Semigroup where A: Semigroup, B: Semigroup {
    public static func <>(lhs: Tuple2, rhs: Tuple2) -> Tuple2 {
        return Tuple2(lhs.a <> rhs.a, lhs.b <> rhs.b)
    }
}
extension Tuple2: Average where A: FloatingPoint, B == Int {
    public typealias AverageType = A
    public var avg: AverageType {
        return a / A(b)
    }
}
public struct FloatAverage<A: FloatingPoint>: Semigroup, Average {
    let tuple: Tuple2<A, Int>
    public typealias AverageType = A
    
    public init(sum: A, count: Int) {
        self.tuple = Tuple2(sum, count)
    }
    public init(_ a: A) {
        self.tuple = Tuple2(a, 1)
    }
    
    public static func <>(lhs: FloatAverage, rhs: FloatAverage) -> FloatAverage {
        return FloatAverage(
            sum: lhs.tuple.a + rhs.tuple.a,
            count: lhs.tuple.b + rhs.tuple.b
        )
    }
    public var avg: AverageType {
        return self.tuple.avg
    }
}
public typealias CGFloatAverage = FloatAverage<CGFloat>

// We need ExpressibleByVoidLiteral!
public struct Unit {}

/// The average of two units is unit
extension Unit: Monoid {
  public static let unit = Unit()
  
  public static func <>(lhs: Unit, rhs: Unit) -> Unit {
    return lhs
  }
  public static var empty: Unit {
    return unit
  }
}

extension Unit: Average {
    public typealias Average = ()
    public var avg: () {
        return
    }
}
