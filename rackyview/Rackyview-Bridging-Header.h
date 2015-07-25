//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//
#import "rngCrypt.h"

#ifndef __rackyview__rngCrypt__
#define __rackyview__rngCrypt__

#include <stdio.h>
unsigned char* rackyEncrypt(const unsigned char*, const unsigned char*, int, int*);
unsigned char* rackyDecrypt(const unsigned char*, const unsigned char*, int, int*);

#endif /* defined(__rackyview__rngCrypt__) */
