//: Playground - noun: a place where people can play

import UIKit

var str = "Hello, playground"

typealias Position = CGPoint
typealias Distance = CGFloat

func inRange1(target: Position, range: Distance) -> Bool {
    return sqrt(target.x * target.x + target.y * target.y) <= range
}

func inRange2(target: Position, ownPosition: Position, range: Distance) -> Bool {
    let dx = ownPosition.x - target.x
    let dy = ownPosition.y - target.y
    let targetDistance = sqrt(dx * dx + dy * dy)
    return targetDistance <= range
}

inRange1(target: CGPoint(x: 1, y: 1), range: 2.0)

inRange2(target: CGPoint(x: 1, y: 1), ownPosition: CGPoint(x: 3, y: 3), range: 2.5)

let minimumDistance: Distance = 2.0

func inRange3(target: Position, ownPosition: Position, range: Distance) -> Bool {
    let dx = ownPosition.x - target.x
    let dy = ownPosition.y - target.y
    let targetDistance = sqrt(dx * dx + dy * dy)
    return targetDistance <= range && targetDistance > minimumDistance
}

inRange3(target: CGPoint(x: 1, y: 1), ownPosition: CGPoint(x: 3, y: 3), range: 3.5)


func pointInRange(point: Position) -> Bool {
    return true
}

typealias Region = (Position) -> Bool

func circle (radius: Distance) -> Region {
    return { point in
        sqrt(point.x * point.x + point.y * point.y) <= radius
    }
}

func circle2(radius: Distance, center: Position) -> Region {
    return { point in
        let shiftedPoint = Position(x: point.x - center.x,
                                    y: point.y - center.y)
        return sqrt(shiftedPoint.x * shiftedPoint.x + shiftedPoint.y * shiftedPoint.y) <= radius
    }
}

func shift(offset: Position, region: @escaping Region) -> Region {
    return { point in
        let shiftedPoint = Position(x: point.x - offset.x,
                                    y: point.y - offset.y)
        return region(shiftedPoint)
    }
}

shift(offset: Position(x: 5, y: 5), region: circle(radius: 10.0))

func invert(region: @escaping Region) -> Region {
    return {point in !region(point) }
}

func intersection (region1: @escaping Region, region2: @escaping Region) -> Region {
    return { point in region1(point) && region2(point) }
}



