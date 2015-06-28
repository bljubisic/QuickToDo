import UIKit


typealias Position = CGPoint
typealias Distance = CGFloat


typealias Region = Position -> Bool

func circle(radius: Distance) -> Region {
    return { point in
        sqrt(point.x * point.x + point.y * point.y) <= radius
    }
}


let reg = circle(10)

reg(Position(x: 9, y: 1))


let testVar: String? = nil

let nextVar = testVar?.uppercaseString


let newVar = nextVar?.lowercaseString




























