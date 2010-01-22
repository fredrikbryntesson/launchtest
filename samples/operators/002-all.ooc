Test: class {

    new: static func -> Test { null }
    
}

operator + (first, second: Test) {
	println("+ works")
}

operator - (first, second: Test) {
	println("- works")
}

operator * (first, second: Test) {
	println("* works")
}

operator / (first, second: Test) {
	println("/ works")
}

operator == (first, second: Test) -> Bool {
	println("== works")
	return true;
}

operator != (first, second: Test) -> Bool {
	println("!= works")
	return true;
}

operator < (first, second: Test) -> Bool {
	println("< works")
	return true;
}

operator <= (first, second: Test) -> Bool {
	println("<= works")
	return true;
}

operator >= (first, second: Test) -> Bool {
	println(">= works")
	return true;
}

operator > (first, second: Test) -> Bool {
	println("> works")
	return true;
}

operator = (first, second: Test) -> Bool {
	println("= works")
	return true;
}

operator += (first, second: Test) -> Bool {
	println("+= works")
	return true;
}

operator -= (first, second: Test) -> Bool {
	println("-= works")
	return true;
}

operator *= (first, second: Test) -> Bool {
	println("*= works")
	return true;
}

operator /= (first, second: Test) -> Bool {
	println("/= works")
	return true;
}

operator []= (first: Test, second: Int, third: Test) {
	println("[]= works")
}

operator [] (first: Test, second: Int) {
	println("[] works")
}

main: func {
    
	one := Test new()
	two := Test new()
    
    one[123]
	one + two
	one - two
	one * two
	one / two
    one << two
    one >> two
    one ^ two
    one & two
    one | two
    
    one[123] = two
	one += two
	one -= two
	one *= two
	one /= two
    one <<= two
    one >>= two
    one ^= two
    one &= two
    one | two
    
    one && two
    one || two
    one % two
    one = two
    one == two
    one >= two
	one <= two
	one != two
    !one
	one > two
    one < two
    ~one
    one as String
	
}

