//: Playground - noun: a place where people can play

import UIKit

var str = "Hello, playground"

protocol Bird {
    var name: String { get }
    var canFly: Bool { get }
}

protocol Flyable {
    var airspeedVelocity: Double { get }
}

struct FlappyBird: Bird, Flyable {
    let name: String
    let flappyAmplitude: Double
    let flappyFrequency: Double
    
    var airspeedVelocity: Double {
        return 3 * flappyFrequency * flappyAmplitude
    }
}

struct Penguin: Bird {
    let name: String
    let canFly: Bool
}

struct swiftBird: Bird, Flyable {
    var name: String { return "Swift \(version)" }
    let version: Double
    
    var airspeedVelocity : Double { return 2000.0 }
}

extension Bird where Self: Flyable {
    var canFly: Bool { return true }
}

enum unladenSwallow: Bird, Flyable {
    case African
    case European
    case Unknown
    
    var name: String {
        switch self {
        case .African:
            return "African"
        case .European:
            return "European"
        case .Unknown:
            return "Unknown"
        }
    }
    
    var airspeedVelocity: Double {
        switch self {
        case .African:
            return 10.0
        case .European:
            return 9.0
        case .Unknown:
            fatalError("You are thrown from the bridge of death!")
        }
    }
}

extension Collection {
    func skip(skip: Int) -> [Generator.Element] {
        guard skip != 0 else { return [] }
        
        var index  = self.startIndex
        var result: [Generator.Element] = []
        var i = 0
        repeat {
            if i % skip == 0 {
                result.append(self[index])
            }
            index = self.index(after: index)
            i+=1
        } while (index != self.endIndex)
        return result
    }
    
}

let bunchaBirds: [Bird] =
    [unladenSwallow.African,
     unladenSwallow.European,
     unladenSwallow.Unknown,
     Penguin(name: "King Penguin", canFly: false),
     swiftBird(version: 2.0),
     FlappyBird(name: "Felipe", flappyAmplitude: 3.0, flappyFrequency: 20.0)]

bunchaBirds.skip(skip: 3)


