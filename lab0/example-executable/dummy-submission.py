#!/usr/bin/python3
# Dummy program for ECE361
# Generate the first 'n' prime numbers (up to 10,000)
#   - 'n' is provided from stdin

import sys

numPrimes = input("Provide the number of prime numbers to generate: ")
numPrimes = int(numPrimes)

print("Generating %s prime numbers..." % numPrimes)

primesFound = 0
candidateNum = 2
for primesGenerated in range(10000):
    isPrime = True

    for i in range(2, int(candidateNum / 2) + 1):
        if (candidateNum % i == 0 and candidateNum != i):
            isPrime = False
            break

    if isPrime:
        print("Found prime: %s" % candidateNum)
        primesFound += 1
        if primesFound == numPrimes:
            sys.exit(0)

    candidateNum += 1

