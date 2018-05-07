import Foundation
import UIKit
import AnimationsCore

let step1: Animation<CGFloatAverage> = linear(from: 0, to: 200, in: 1)
let step2: Animation<CGFloatAverage> = linear(from: 50, to: 200, in: 3)
let step3: Animation<CGFloatAverage> = linear(from: 200, to: 300, in: 1)
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

let paralleled: Animation<CGFloatAverage> = step1 + step2

paralleled.value(0)
paralleled.value(0.2)
paralleled.value(0.4)
paralleled.value(0.6)
paralleled.value(0.8)
paralleled.value(1)

// verification of associativity:
let assoc1 = step1 * (step2 * step3)
let assoc2 = (step1 * step2) * step3
"\(assoc1.value(0.5)!.avg) == \(assoc2.value(0.5)!.avg)"
"\(assoc1.value(0.25)!.avg) == \(assoc2.value(0.25)!.avg)"
"\(assoc1.value(0.75)!.avg) == \(assoc2.value(0.75)!.avg)"

// verification of associativity, commutativity of +
let assocP1: Animation<CGFloatAverage> = step1 + (step2 + step3)
let assocP2: Animation<CGFloatAverage> = (step1 + step2) + step3
let commuteP: Animation<CGFloatAverage> = (step2 + step1) + step3
"\(assocP1.value(0.5)!.avg) == \(assocP2.value(0.5)!.avg) == \(commuteP.value(0.5)!.avg)"
"\(assocP1.value(0.25)!.avg) == \(assocP2.value(0.25)!.avg) == \(commuteP.value(0.25)!.avg)"
"\(assocP1.value(0.75)!.avg) == \(assocP2.value(0.75)!.avg) == \(commuteP.value(0.75)!.avg)"

// verification of distributivity:

let distLhs = step1 * (step2 + step3)
let distRhs = (step1 * step2) + (step1 * step3)
"\(distLhs.value(0.1)!.avg) == \(distRhs.value(0.1)!.avg)"
"\(distLhs.value(0.2)!.avg) == \(distRhs.value(0.2)!.avg)"
"\(distLhs.value(0.3)!.avg) == \(distRhs.value(0.3)!.avg)"
"\(distLhs.value(0.4)!.avg) == \(distRhs.value(0.4)!.avg)"
"\(distLhs.value(0.5)!.avg) == \(distRhs.value(0.5)!.avg)"
"\(distLhs.value(0.6)!.avg) == \(distRhs.value(0.6)!.avg)"

// verification of multiplicative identity
let onLeft = step1 * .one
let onRight = .one * step1
"\(step1.value(0.5)!.avg) == \(onLeft.value(0.5)!.avg) == \(onRight.value(0.5)!.avg)"
"\(step1.value(0.25)!.avg) == \(onLeft.value(0.25)!.avg) == \(onRight.value(0.25)!.avg)"
"\(step1.value(0.75)!.avg) == \(onLeft.value(0.75)!.avg) == \(onRight.value(0.75)!.avg)"

// verification of additive identity
let onLeft_ = step1 + .zero
let onRight_ = .zero + step1
"\(step1.value(0.5)!.avg) == \(onLeft_.value(0.5)!.avg) == \(onRight_.value(0.5)!.avg)"
"\(step1.value(0.25)!.avg) == \(onLeft_.value(0.25)!.avg) == \(onRight_.value(0.25)!.avg)"
"\(step1.value(0.75)!.avg) == \(onLeft_.value(0.75)!.avg) == \(onRight_.value(0.75)!.avg)"

// verification of annihalation of zero
let annLeft = .zero * step1
let annRight = step1 * .zero
"\(Animation<CGFloatAverage>.zero) == \(annLeft) == \(annRight)"

// Therefore we have a semiring (with no additive identity)!
// it's also morally an idempotent semiring if you consider two things equivalent that have the same averages


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





