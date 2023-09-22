import UIKit

var str = "Hello, playground"

typealias Position = CGPoint
typealias Distance = CGFloat

typealias Region = (Position) -> Bool

func circle(radius: Distance) -> Region {
    return { point in
        sqrt(point.x * point.x + point.y * point.y) <= radius
    }
}


circle(radius: 10)(CGPoint(x: 5, y: 5))

for hourOffset in 0 ... 4 {
    print(hourOffset)
}


