//
//  Demonstration.swift
//  AnimationsCore
//
//  Created by Brandon Kase on 5/19/18.
//

import Foundation
import UIKit

public indirect enum FreeSemiring<A>: Semiring {
    case _one
    case _zero
    case single(A)
    case times(FreeSemiring<A>, FreeSemiring<A>)
    case plus(FreeSemiring<A>, FreeSemiring<A>)
    
    public static var one: FreeSemiring<A> { return ._one }
    
    public static var zero: FreeSemiring<A> { return ._zero }
    

    public static func *(lhs: FreeSemiring, rhs: FreeSemiring) -> FreeSemiring {
        return .times(lhs, rhs)
    }
    
    public static func +(lhs: FreeSemiring, rhs: FreeSemiring) -> FreeSemiring {
        return .plus(lhs, rhs)
    }
    
    public func map<B>(_ f: (A) -> B) -> FreeSemiring<B> {
        switch self {
        case ._one:
            return ._one
        case ._zero: return ._zero
        case .single(let a): return .single(f(a))
        case .times(let l, let r): return .times(l.map(f), r.map(f))
        case .plus(let l, let r): return .plus(l.map(f), r.map(f))
        }
    }
    
    /* Forget the structure and just give back the As */
    public func forget() -> [A] {
        switch self {
        case ._one: return []
        case ._zero: return []
        case .single(let a): return [a]
        case .times(let l, let r): return l.forget() + r.forget()
        case .plus(let l, let r): return l.forget() + r.forget()
        }
    }
}

extension FreeSemiring where A : Semiring {
    public func interpret() -> A {
        switch self {
        case ._one: return A.one
        case ._zero: return A.zero
        case .single(let a): return a
        case .times(let l, let r): return l.interpret() * r.interpret()
        case .plus(let l, let r): return l.interpret() + r.interpret()
        }
    }
}

public struct SceneFragment {
    public let name : String
    public let animation : Animation<Unit>
    public init(_ name: String, _ animation: Animation<Unit>) {
        self.name = name
        self.animation = animation
    }
}

func stretchRight(view: UIView, pixels: Int, in: CFAbsoluteTime) -> Animation<AnimationsCore.Unit> {
    let startWidth = view.bounds.width
    let changePercent = CGFloat(pixels) / CGFloat(startWidth)
    return (linear(from: 1, to: changePercent, in: 2)
        .bind(view, with: \.transform.a)) +
        (linear(from: 1, to: (CGFloat(pixels) - CGFloat(startWidth))/2, in: 2)
            .bind(view, with: \.transform.tx))
}

public struct Scene {
    public let fragments : FreeSemiring<SceneFragment>
    public let actors : [UIView]
    
    public init(fragments : FreeSemiring<SceneFragment>, actors: [UIView]) {
        self.fragments = fragments
        self.actors = actors
    }
    
    private static func longestTime(_ intervals: [(String, CFAbsoluteTime, CFAbsoluteTime)]) -> CFAbsoluteTime {
        print(intervals)
        return intervals.map{ $0.2 }.sorted{ $0 < $1 }.last ?? 0
    }
    
    private static func intervals(_ frags: FreeSemiring<SceneFragment>) -> [(String, Double, Double)] {

        func helper(_ a: FreeSemiring<SceneFragment>, _ currDuration: CFAbsoluteTime, _ build: [(String, CFAbsoluteTime, CFAbsoluteTime)]) -> [(String, CFAbsoluteTime, CFAbsoluteTime)] {
            switch a {
            case ._one: return build
            case ._zero: return []
            case .single(let a): return build + [(a.name, currDuration, currDuration+a.animation.duration)]
            case .plus(let l, let r):
                let lBuild = helper(l, currDuration, build)
                return helper(r, currDuration, lBuild)
            case .times(let l, let r):
                let lBuild = helper(l, currDuration, build)
                let next = longestTime(lBuild)
                return helper(r, currDuration+next, lBuild)
            }
        }
        
        return helper(frags, 0, [])
    }
    
    private func timeline(start: CFAbsoluteTime, end: CFAbsoluteTime, height: CGFloat, totalDuration: CFAbsoluteTime, totalWidth: CGFloat, labelOffsetX: CGFloat) -> (Animation<Unit>, UIView) {
        print(totalDuration)
        let diff = end-start
        let ratio = diff / totalDuration
        let endWidth = CGFloat(ratio) * totalWidth
        
        
        // 0|_________________|100
        //         ^
        //         25
        //                     |500px
        //  25/100 = x/500px
        let moreOffset = CGFloat(start / totalDuration) * totalWidth

        let view = UIView(frame: .init(x: 0, y: 0, width: 1, height: height))
        view.backgroundColor = UIColor.cyan
        
        let guide = UIView(frame: .init(x: 0, y: 0, width: endWidth, height: height))
        guide.backgroundColor = UIColor.cyan
        guide.alpha = 0.2
        
        let container = UIView(frame: .init(x: labelOffsetX + moreOffset, y: 2, width: totalWidth, height: height))
        container.addSubview(guide)
        container.addSubview(view)
        
        print("Building animation with diff", diff)
        let animation =
            diff == 0 ? .one :
            stretchRight(view: view, pixels: Int(endWidth), in: diff)
                .delayed(by: start)
        return (animation, container)
    }
    
    public func render() -> (UIView, Animation<Unit>) {
        assert(actors.count <= 4)
        assert(actors.count > 0)
        
        let width = 500
        let height = 300
        let padding = CGFloat(10)
        let centerx = CGFloat(width/2)
        let centery = CGFloat(height/2)
        
        let canvas = UIView(frame: .init(x: 0, y: 0, width: width, height: width))
        canvas.backgroundColor = .white
        
        switch actors.count {
        case 1:
            let f = actors[0].frame
            actors[0].frame = CGRect(x: centerx-(f.width/2), y:centery-(f.height/2), width:f.width, height:f.height)
        case 2:
            let f0 = actors[0].frame
            let f1 = actors[1].frame
            actors[0].frame = CGRect(x: centerx-f0.width-padding, y: centery-(f0.height/2), width: f0.width, height: f0.height)
            actors[1].frame = CGRect(x: centerx+padding, y:centery-(f1.height/2), width: f1.width, height: f1.height)
        case 3:
            let f0 = actors[0].frame
            let f1 = actors[1].frame
            let f2 = actors[2].frame
            actors[0].frame = CGRect(x: centerx-f0.width-padding, y: centery-f0.height-padding, width: f0.width, height: f0.height)
            actors[1].frame = CGRect(x: centerx+padding, y:centery-f1.height-padding, width: f1.width, height: f1.height)
            actors[2].frame = CGRect(x: centerx-(f2.width/2), y:centery+padding, width: f2.width, height: f2.height)
        case 4:
            let f0 = actors[0].frame
            let f1 = actors[1].frame
            let f2 = actors[2].frame
            let f3 = actors[3].frame
            actors[0].frame = CGRect(x: centerx-f0.width-padding, y: centery-f0.height-padding, width: f0.width, height: f0.height)
            actors[1].frame = CGRect(x: centerx+padding, y:centery-f1.height-padding, width: f1.width, height: f1.height)
            actors[2].frame = CGRect(x: centerx-f2.width-padding, y:centery+padding, width: f2.width, height: f2.height)
            actors[3].frame = CGRect(x: centerx+padding, y:centery+padding, width: f3.width, height: f3.height)
        default:
            fatalError("impossible")
        }
        
        actors.forEach{ canvas.addSubview($0) }
        
        let cellHeight = 30
        let cellPadding = 5
        let detailsHeight = fragments.forget().count * (cellHeight + cellPadding) + cellPadding*2
        let details = UIView(frame: .init(x: 0, y: height, width: width, height: detailsHeight))
        
        let totalDuration = Scene.longestTime(Scene.intervals(fragments))
        
        let timelineAnimations : [Animation<Unit>] =
        zip(Scene.intervals(fragments), fragments.map{ $0.animation}.forget()).enumerated().map { x in
            let (offset, ((name, start, end), animation)) = x
            let row = UIView(frame: .init(x: 0, y: (cellHeight+cellPadding)*offset, width: width, height: cellHeight+cellPadding))
            row.layer.borderColor = UIColor.black.cgColor
            row.layer.borderWidth = 1
            
            let labelWidth = 150
            let label = UILabel(frame: .init(x: cellPadding, y: cellPadding, width: labelWidth, height: cellHeight - cellPadding))
            label.text = name
            label.font = UIFont.systemFont(ofSize: 24)
            
            let sep = UIView(frame: .init(x: labelWidth, y: 0, width: 2, height: cellHeight+cellPadding))
            sep.backgroundColor = .black
            
            row.addSubview(label)
            row.addSubview(sep)
            let (tAnim, tView) = timeline(start: start, end: end, height: CGFloat(cellHeight+cellPadding)-4, totalDuration: totalDuration, totalWidth: CGFloat(width-labelWidth), labelOffsetX: CGFloat(labelWidth)+1)
            row.addSubview(tView)
            
            details.addSubview(row)
            return tAnim
        }
        let totalAnimation : Animation<Unit> = timelineAnimations.reduce(Animation<Unit>.zero){ $0 + $1 }
        
        let container = UIView(frame: .init(x: 0, y: 0, width: width, height: height + detailsHeight))
        container.backgroundColor = .white
        container.addSubview(canvas)
        container.addSubview(details)
        
        return (container,
                fragments.map{ $0.animation }.interpret() + totalAnimation)
    }
}
