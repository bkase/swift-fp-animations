import Foundation
import AnimationsCore
import UIKit

let step1 = linear(from: 0, to: 200, in: 1)
let step2 = linear(from: 50, to: 200, in: 3)
let step3 = linear(from: 200, to: 300, in: 1)
let sequenced = step1 * step2 * step3

extension CGAffineTransform {
  // helper for setting the absolute rotation of a CGAffineTransform.
  // It would prob be better to define a type with just rotation and translation
  // and then derive `transform` from it.
  var rotation: CGFloat {
    // boy i wish swift allowed just setters
    get { return 0 }
    set {
      var result = CGAffineTransform(rotationAngle: newValue)
      result.tx = self.tx
      result.ty = self.ty
      self = result
    }
  }
}

sequenced.value(0)
sequenced.value(0.2)
sequenced.value(0.4)
sequenced.value(0.6)
sequenced.value(0.8)
sequenced.value(1)

let paralleled = step1 + step2

paralleled.value(0)
paralleled.value(0.2)
paralleled.value(0.4)
paralleled.value(0.6)
paralleled.value(0.8)
paralleled.value(1)

// verification of associativity:
let assoc1 = step1 * (step2 * step3)
let assoc2 = (step1 * step2) * step3
"\(assoc1.value(0.5).avg) == \(assoc2.value(0.5).avg)"
"\(assoc1.value(0.25).avg) == \(assoc2.value(0.25).avg)"
"\(assoc1.value(0.75).avg) == \(assoc2.value(0.75).avg)"

// verification of associativity, commutativity of +
let assocP1 = step1 + (step2 + step3)
let assocP2 = (step1 + step2) + step3
let commuteP = (step2 + step1) + step3
"\(assocP1.value(0.5).avg) == \(assocP2.value(0.5).avg) == \(commuteP.value(0.5).avg)"
"\(assocP1.value(0.25).avg) == \(assocP2.value(0.25).avg) == \(commuteP.value(0.25).avg)"
"\(assocP1.value(0.75).avg) == \(assocP2.value(0.75).avg) == \(commuteP.value(0.75).avg)"

// (almost) proof of (one-side) of distributivity
// let A, B, C be animations
// WTS: A * (B + C) = A * B + A * C
// ->
//  A * (B + C)
//  A * (B <> C) (since + forms a semigroup now)
//  A and then (B <> C) (by definition)
//  (A and-then B) <> (A and-then C) (I can't prove this step but it feels right Please help here)
//  (A * B) + (A * C) by defition

// verification of distributivity:

let distLhs = step1 * (step2 + step3)
let distRhs = (step1 * step2) + (step1 * step3)
"\(distLhs.value(0.1).avg) == \(distRhs.value(0.1).avg)"
"\(distLhs.value(0.2).avg) == \(distRhs.value(0.2).avg)"
"\(distLhs.value(0.3).avg) == \(distRhs.value(0.3).avg)"
"\(distLhs.value(0.4).avg) == \(distRhs.value(0.4).avg)"
"\(distLhs.value(0.5).avg) == \(distRhs.value(0.5).avg)"
"\(distLhs.value(0.6).avg) == \(distRhs.value(0.6).avg)"

// verification of multiplicative identity
let onLeft = step1 * .one
let onRight = .one * step1
"\(step1.value(0.5).avg) == \(onLeft.value(0.5).avg) == \(onRight.value(0.5).avg)"
"\(step1.value(0.25).avg) == \(onLeft.value(0.25).avg) == \(onRight.value(0.25).avg)"
"\(step1.value(0.75).avg) == \(onLeft.value(0.75).avg) == \(onRight.value(0.75).avg)"

// Therefore we have a semiring (with no additive identity)!
// it's also morally an idempotent semiring if you consider two things equivalent that have the same averages


// recover the tupling operation
typealias AaToBbToAb<A: Semigroup, B: Semigroup> = FunctionS<Tuple2<A, A>, FunctionS<Tuple2<B, B>, Tuple2<A, B>>>
infix operator ++: AdditionPrecedence
func ++<A,B>(lhs: Animation<A>, rhs: Animation<B>) -> Animation<Tuple2<A, B>> {
  let aa = lhs.map{ a in Tuple2<A, A>(a, a) }
  let bb = rhs.map{ b in Tuple2<B, B>(b, b) }
  let f = AaToBbToAb<A, B> { aa in
    return FunctionS { bb in Tuple2<A, B>(aa.a, bb.b) }
  }
  let af = const(value: f, duration: max(aa.duration, bb.duration))
  return ap(ap(af, aa), bb)
}

let redSquare = UIView(frame: .init(x: 0, y: 0, width: 100, height: 100))
redSquare.backgroundColor = .red

let blueSquare = UIView(frame: .init(x: 0, y: 200, width: 100, height: 100))
blueSquare.backgroundColor = .blue

let container = UIView(frame: .init(x: 0, y: 0, width: 400, height: 400))
container.backgroundColor = .white
container.addSubview(redSquare)
container.addSubview(blueSquare)

import PlaygroundSupport

PlaygroundPage.current.liveView = container
PlaygroundPage.current.needsIndefiniteExecution = true

let driver = Drive(maxSteps: 500)

let redAnimation =
  linear(from: 300, to: 0, in: 1)
    .transformTime(easeOut(2))
    .looped
    .delayed(by: 1)
    .repeating(count: Int.max)
    .bind(redSquare, with: \.transform.ty)
    // rotate back and forth
//    + step1
//      .map { $0/20 }
//      .looped
//      .repeating(count: 4)
//      .bind(redSquare, with: \.transform.rotation)

let blueAnimation =
  step1
    .transformTime(easeOut)
    .looped
    .delayed(by: 1)
    .repeating(count: Int.max)
    .bind(blueSquare, with: \.transform.tx)

let final = redAnimation ++ blueAnimation

DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
  driver.append(animation: final.map { _ in Unit.unit })
}



print("✅")





