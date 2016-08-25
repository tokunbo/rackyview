//
//Disclaimer: I'm not a cryptography master. This was redone in C, following a program written in Csharp, which was redone to mimic the assembly code of a Nintendo
//Pokemon game in an emulator project. And I didn't understand all of the code so I improvised and added stuff. Lots of stuff. Now this code has very little in common with whatever I was trying to copy.
//Yes, I know writing my own crypto is pretty much asking for trouble... but it's fun and the iOS keychain is the first line of defense here anyway, not my encryption.

#include <string.h>
#include <stdlib.h>

unsigned char* rackyEncrypt(unsigned const char* plaintext, unsigned const char* key, int in_length, int* out_length) {
    int i=0, q=0, rand_seed=0, rand_mult=0, rand_add=0, rand_mask=0, checksum=0, step1, step2, step3;
    unsigned char* buf;
    long key_length = strlen((const char*)key);
    *out_length = 0;
    if(!plaintext || !key || in_length < 1 || key_length < 36 || !out_length) {
        return NULL;
    }

    for(q=0; q<in_length; q++) {
        checksum += plaintext[q];
    }
    *out_length = in_length + 12 + (checksum & 0xF);
    buf = malloc(*out_length);
    rand_seed = checksum | (checksum << 16);
    for(q=0; q<6; q++) {
        rand_mult = rand_mult << 8;
        rand_mult += (char)(key[i]+key[i+1]);
        i += 2;
    }
    for(q=0; q<6; q++) {
        rand_add = rand_add << 8;
        rand_add += (char)(key[i]+key[i+1]);
        i += 2;
    }
    for(q=0; q<6; q++) {
        rand_mask = rand_mask << 8;
        rand_mask += (char)(key[i]+key[i+1]);
        i += 2;
    }
    step1 = rand_seed * rand_mult;
    step2 = step1 + rand_add;
    step3 = ((step2 & ~rand_mask) >> 16) & 0xff;
    
    //I wish someone told me decades ago that I could cast a char* into an int* and access 4 bytes at a time.
    //Easily the most valuable lesson I gained from writing this.
    *((int*)buf) = checksum ^ *((int*)key);
    *((int*)(buf+4)) = in_length ^ *((int*)(key+4));
    *((int*)(buf+8)) = step3 ^ *((int*)(key+8));
    for(q=0; q<key_length; q++) {
        buf[q%12] ^= key[q];
    }
    for(q=0; q<in_length+(checksum & 0xF); q++) {
        buf[q+12] = plaintext[q] ^ (step3 >> q%32)  ^ key[q%key_length] ^ (checksum >> q%32);//Yes, this can end up reading beyond plaintext's memory.
        step3++;
        checksum--;
    }
    return buf;
}

unsigned char* rackyDecrypt(unsigned const char* ciphertext, unsigned const char* key, int in_length, int* out_length) {
    int q, checksum=0, finalstep=0;
    unsigned char* buf;
    long key_length = strlen((const char*)key);
    *out_length = 0;
    if(!ciphertext || !key || key_length < 36 || in_length < 1 || !out_length) {
        return NULL;
    }
    buf = malloc(12);
    memcpy(buf, ciphertext, 12);
    for(q=0; q<key_length; q++) {
        buf[q%12] ^= key[q];
    }
    checksum = *((int*)buf) ^ *((int*)key);
    *out_length = *((int*)(buf+4)) ^ *((int*)(key+4));
    finalstep = *((int*)(buf+8)) ^ *((int*)(key+8));
    if(*out_length > in_length) {//Impossible condition. Must be the wrong key.
        free(buf);
        *out_length = 0;
        return NULL;
    }
    buf = realloc(buf, *out_length);
    for(q=0; q<*out_length; q++) {
        buf[q] = ciphertext[q+12] ^ (finalstep  >> q%32) ^ key[q%key_length] ^ (checksum  >> q%32);
        finalstep++;
        checksum--;
    }
    return buf;
}