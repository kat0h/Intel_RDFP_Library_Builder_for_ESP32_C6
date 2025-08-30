#include <Arduino.h>
#include "bid_conf.h"
#include "bid_functions.h"

void setup() {
	Serial.begin(115200);
}

void loop() {
	BID_UINT128 a, b, c, result;
    char output[64];

    Serial.printf("\n=== Intel Decimal Floating-Point Math Library Arithmetic Functions Test ===\n");

    // Basic arithmetic operations test
    Serial.printf("\n=== Basic Arithmetic Operations Test ===\n");
    __bid128_from_string(&a, "123.456");
    __bid128_from_string(&b, "78.9");
    __bid128_from_string(&c, "2.0");

    // Addition
    __bid128_add(&result, &a, &b);
    __bid128_to_string(output, &result);
    Serial.printf("123.456 + 78.9 = %s\n", output);
	 
	delay(1);
}

