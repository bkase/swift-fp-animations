import CoreGraphics

public func linear(from a: CGFloat, to b: CGFloat, in duration: CFAbsoluteTime) -> Animation<FloatAverage<CGFloat>> {
  return Animation(duration: duration) { t in
    FloatAverage(a * (1 - CGFloat(t)) + b * CGFloat(t))
  }
}

