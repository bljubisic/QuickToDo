
var text: String = String()

text = "test"

text += " new"

var testArray: [String] = [String]()

testArray.append(text)

var testDict: [String: String] = [String: String]()

var key: String = "Key"

testDict[key] = text

println(testDict[key])

var textNew = "key \(key)"


























