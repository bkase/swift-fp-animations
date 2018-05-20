import Foundation
import UIKit
import AnimationsCore

let step1: Animation<CGFloatAverage> = linear(from: 0, to: 200, in: 1)
/*let step2: Animation<CGFloatAverage> = linear(from: 50, to: 200, in: 3)
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

*/
class CircleMaskView : UIView {
    override init(frame:CGRect) {
        super.init(frame:frame)
        self.isOpaque = false
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func draw(_ rect: CGRect) {
        let con = UIGraphicsGetCurrentContext()
        UIColor.black.setFill()
        con?.fillEllipse(in: rect)
    }
}

let driver = Drive(maxSteps: 500)

import PlaygroundSupport

func circle(x: Int, y: Int, radius: Int) -> UIView {
    let view = UIView(frame: .init(x: x - radius, y: y - radius, width: radius*2, height: radius*2))
    let mask = CircleMaskView(frame:view.bounds)
    view.mask = mask
    return view
}

let actor = circle(x: 200, y: 200, radius: 50)
actor.backgroundColor = .blue

let actor2 = UIView(frame: .init(x: 0, y: 0, width: 100, height: 100))
actor2.backgroundColor = .red
actor2.alpha = 0

func circleCurve(from: CGFloat, to: CGFloat) -> Animation<CGFloatAverage> {
    
    return
        (linear(from: from, to: to, in: 2)
            .transformTime(easeInOut) * const(value: CGFloatAverage(to), duration: 0.3))
}

let growCircle =
    circleCurve(from: 10, to: 100)
        .do { x in
            let rect = CGRect(origin: .zero, size: CGSize(width: x.avg, height: x.avg))
            (actor.mask!.frame = rect)
            (actor.bounds = rect)
}
let fadeOut =
    circleCurve(from: 1, to: 0)
        .bind(actor, with: \.alpha)
let fadeInRed =
    circleCurve(from: 0, to: 1)
        .bind(actor2, with: \.alpha)

func stretchRight(view: UIView, pixels: Int, in: CFAbsoluteTime) -> Animation<AnimationsCore.Unit> {
    let startWidth = view.bounds.width
    let changePercent = CGFloat(pixels) / CGFloat(startWidth)
    return (linear(from: 1, to: changePercent, in: 2)
        .bind(view, with: \.transform.a)) +
    (linear(from: 1, to: (CGFloat(pixels) - CGFloat(startWidth))/2, in: 2)
        .bind(view, with: \.transform.tx))

}

let scene = Scene(
    fragments:
    .plus(
        .times(
            .single(SceneFragment("growCircle", growCircle)),
            .single(SceneFragment("fadeOutBlue", fadeOut))),
        .single(SceneFragment("fadeInRed",
                fadeInRed))
        ),
    actors: [actor, actor2]
)

let (container, final) = scene.render()


PlaygroundPage.current.liveView = container
PlaygroundPage.current.needsIndefiniteExecution = true

DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    driver.append(animation: final)
}

print("✅")





