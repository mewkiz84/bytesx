package bytesx_test

import (
	"testing"
	"fmt"
	"github.com/mewkiz84/bytesx"
	"syscall"
	"unsafe"
)

var test1 = []byte("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
var test2 = []byte("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")

func TestIndexNotEqual(t *testing.T) {
	// Test special cases
	if -1 != bytesx.IndexNotEqual([]byte(""), []byte("X")) {
		t.Errorf("IndexNotEqual test failed. String1: \"\" String2: \"X\"")
	}
	if -1 != bytesx.IndexNotEqual([]byte(""), []byte("")) {
		t.Errorf("IndexNotEqual test failed. String1: \"\" String2: \"\"")
	}
	if -1 != bytesx.IndexNotEqual([]byte("a"), []byte("aX")) {
		t.Errorf("IndexNotEqual test failed. String1: \"a\" String2: \"aX\"")
	}
	if -1 != bytesx.IndexNotEqual([]byte("aX"), []byte("a")) {
		t.Errorf("IndexNotEqual test failed. String1: \"aX\" String2: \"a\"")
	}

	// Test all length of data from 1 to 128 bytes with a non matching byte in every
	// possibe possition and all length of strings from 1 to 128 where the data is
	// the same.
	for i, _ := range test1 {
		for j := 0; j < i; j++ {
			test2[j] = 'X'
			got := bytesx.IndexNotEqual(test1[:i], test2[:i])
			test2[j] = 'A'
			if got != j {
				t.Errorf("IndexNotEqual test failed. \nGot:%d\nString1: %d \"A\"s\nString2: %d \"A\"s plus a \"X\" at possition %d \nExpected: %d ", got, i, i-1, j, j)
			}
		}
		got := bytesx.IndexNotEqual(test1[:i], test2[:i])
		if got != -1 {
			t.Errorf("IndexNotEqual test failed. Got:%d\nString1: %d \"A\"s\nString2: %d \"A\"s\nExpected: -1 ", got, i, i)
		}
	}
}

func TestEqualNearPageBoundary(t *testing.T) {
	pagesize := syscall.Getpagesize()
	b := make([]byte, 4*pagesize)
	i := pagesize
	for ; uintptr(unsafe.Pointer(&b[i]))%uintptr(pagesize) != 0; i++ {
	}
	syscall.Mprotect(b[i-pagesize:i], 0)
	syscall.Mprotect(b[i+pagesize:i+2*pagesize], 0)
	defer syscall.Mprotect(b[i-pagesize:i], syscall.PROT_READ|syscall.PROT_WRITE)
	defer syscall.Mprotect(b[i+pagesize:i+2*pagesize], syscall.PROT_READ|syscall.PROT_WRITE)

	// both of these should fault
	//pagesize += int(b[i-1])
	//pagesize += int(b[i+pagesize])

	for j := 0; j < pagesize; j++ {
		b[i+j] = 'A'
	}
	for j := 0; j <= pagesize; j++ {
		fmt.Println(j)
		bytesx.EqualThreshold(b[i:i+j], b[i+pagesize-j:i+pagesize], 0)
		bytesx.EqualThreshold(b[i+pagesize-j:i+pagesize], b[i:i+j], 0)
	}
}

func TestEqualThreshold(t *testing.T) {
	// Test special cases
	if true != bytesx.EqualThreshold([]byte(""), []byte("X"), 0) {
		t.Errorf("EqualThreshold test failed. String1: \"\" String2: \"X\" Threshold: 0")
	}
	if true != bytesx.EqualThreshold([]byte("X"), []byte(""), 0) {
		t.Errorf("EqualThreshold test failed. String1: \"\" String2: \"\"")
	}
	if true != bytesx.EqualThreshold([]byte(""), []byte(""), 0) {
		t.Errorf("EqualThreshold test failed. String1: \"a\" String2: \"aX\"")
	}

	fmt.Println("Testing all threshold values for strings up to 128 bytes")
	fmt.Println("Total number of tests: 2'147'483'648")
	fmt.Println("This will take 1-2 min")
	for i := 1; i < 128; i++ {
		for a := 0; a < 256; a++ {
			for b := 0; b < 256; b++ {
				for th := 0; th < 256; th++ {
					// set test1 and test2 to the same data at all positions
					for neq := bytesx.IndexNotEqual(test1, test2); -1 != neq; neq = bytesx.IndexNotEqual(test1, test2) {
						test1[neq] = 'A'
						test2[neq] = 'A'
					}

					test1[i-1] = byte(a)
					test2[i-1] = byte(b)

					diff := 0
					if a > b {
						diff = a - b
					} else {
						diff = b - a
					}

					got := bytesx.EqualThreshold(test1[:i], test2[:i], byte(th))
					ans := th >= diff

					if ans != got {
						t.Errorf("\nEqualThreshold test failed.\nGot:  %v\nAns:  %v\nStr1: %s\nStr2: %s\nTH:   %d\nDiff: %d\nLen:  %d", got, ans, test1[:i], test2[:i], byte(th), diff, i)
					}
				}
			}
		}
	}
}
