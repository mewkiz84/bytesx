// Package bytesx implements highly optimized byte functions which extends the 
// bytes package in the standard library
package bytesx

// IndexNotEqual returns the index of the first non matching byte between a and
// b, or -1 if a and b are equal untill the shortest of the two.
func IndexNotEqual(a, b []byte) int

// EqualThreshold returns true if b does not differ in value more than t from
// the corresponding byte in a.
// t may take any value from 0 to 255 where 0 is exact match and 255 will match
// any string. If t is 1 and a is "MNO" and b is "LNP" than EqualThreshold will
// return true while it will return false if b is "LNQ" or "KNO". The equality
// check is only made untill the shortest of a and b.
func EqualThreshold(a, b []byte, t uint8) bool
