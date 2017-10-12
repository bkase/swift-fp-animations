//
//  Average.swift
//  AnimationsPackageDescription
//
//  Created by Brandon Kase on 10/12/17.
//

import Foundation


infix operator <>: AdditionPrecedence
public protocol Semigroup {
  static func <>(lhs: Self, rhs: Self) -> Self
}
// you don't _need_ the monoid instance, but it makes recovering the tuple version of `+` less awkward
public protocol Monoid: Semigroup {
  static var empty: Self { get }
}

/// Law: (A <> A).avg = A.avg
public protocol Averagable: Monoid {
  associatedtype Average
  var avg: Average { get }
}

public struct FloatAverage<A: FloatingPoint>: Averagable {
  let sum: A
  let count: Int
  
  public typealias Average = A
  
  public init(_ value: A) {
    self.sum = value
    self.count = 1
  }
  
  private init(sum: A, count: Int) {
    self.sum = sum
    self.count = count
  }
  
  public static func <>(lhs: FloatAverage, rhs: FloatAverage) -> FloatAverage {
    // the empty makes this a little awkward
    let sum = (lhs.sum.isNaN ? 0 : lhs.sum) +
      (rhs.sum.isNaN ? 0 : rhs.sum)
    return FloatAverage(
      sum: sum.isZero ? A.nan : sum,
      count: lhs.count + rhs.count
    )
  }
  
  public static var empty: FloatAverage {
    return FloatAverage(sum: A.nan, count: 0)
  }
  
  public var avg: Average {
    return sum / A(count)
  }
}
// Not sure why I can't get this to work?
/*extension FloatAverage: ExpressibleByFloatLiteral {
 init(floatLiteral: A) {
 self.sum = floatLiteral
 self.count = 1
 }
 }*/
/// The average of two things are just those two things' averages
public struct Tuple2<A: Averagable, B: Averagable>: Averagable {
  public let a: A
  public let b: B
  public init(_ a: A, _ b: B) {
    self.a = a
    self.b = b
  }
  
  public typealias Average = (A.Average, B.Average)
  
  public static var empty: Tuple2 {
    return Tuple2(A.empty, B.empty)
  }
  
  public static func <>(lhs: Tuple2, rhs: Tuple2) -> Tuple2 {
    return Tuple2(lhs.a <> rhs.a, lhs.b <> rhs.b)
  }
  
  public var avg: (A.Average, B.Average) {
    return (a.avg, b.avg)
  }
}

// We need ExpressibleByVoidLiteral!
public struct Unit {}

/// The average of two units is unit
extension Unit: Averagable {
  public typealias Average = ()
  
  public static let unit = Unit()
  
  public static func <>(lhs: Unit, rhs: Unit) -> Unit {
    return lhs
  }
  public static var empty: Unit {
    return unit
  }
  public var avg: () {
    return
  }
}
