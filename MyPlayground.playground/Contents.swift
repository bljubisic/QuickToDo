//: Playground - noun: a place where people can play

import UIKit

var str = "Hello, playground"


func add2(x: Int) -> Int -> Int {
    return  {y in x + y}
}

func add3(x: Int)(_ y: Int) -> Int {
    return x+y
}

add2(1)(2)
add3(1)(4)


func computeIntArray<U>(xs: [Int], f: Int -> U) -> [U] {
    var result: [U] = []
    
    for x in xs {
        result.append(f(x))
    }
    return result
}

func doubleArray(xs: [Int]) -> [Int] {
    return computeIntArray(xs) { x in x * 2}
}

func isEvenArray(xs: [Int]) -> [Bool] {
    return computeIntArray(xs) { x in x % 2 == 0 }
}

var xs: [Int] = [1, 2, 3]

doubleArray(xs)

isEvenArray(xs)

enum result {
    case success()
    case fail()
    
}

var res: result

var suc = result.success()

var i = 0

var itemsMap: [String: String] = ["test": "nesto", "smt": "tst"]

var keys = [String](itemsMap.keys)

keys.count

keys[0]












