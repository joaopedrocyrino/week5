pragma circom 2.0.3;
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";
include "./hasher.circom";

// if s == 0 returns [in[0], in[1]]
// if s == 1 returns [in[1], in[0]]
template DualMux() {
    signal input in[2];
    signal input s;
    signal output out[2]; 

    s * (1 - s) === 0;
    out[0] <== (in[1] - in[0])*s + in[0];
    out[1] <== (in[0] - in[1])*s + in[1];
}

// Verifies that merkle proof is correct for given merkle root and a leaf
// pathIndices input is an array of 0/1 selectors telling whether given pathElement is on the left or right side of merkle path
template ManyMerkleTreeChecker(levels, length, nInputs) {
    signal input leaf[nInputs];
    signal input pathElements[levels];
    signal input pathIndices[levels];
    signal input roots[length];
    signal output out;

    component selectors[levels];
    component hashers[levels];

    component leaf_hasher = Poseidon(nInputs);

    var i = 0;

    for (i = 0; i < nInputs; i++){
        log(leaf[i]);
        leaf_hasher.inputs[i] <== leaf[i];
    }

    for (i = 0; i < levels; i++) {
        selectors[i] = DualMux();
        selectors[i].in[0] <== i == 0 ? leaf_hasher.out : hashers[i - 1].hash;
        selectors[i].in[1] <== pathElements[i];
        selectors[i].s <== pathIndices[i];

        hashers[i] = HashLeftRight();
        hashers[i].left <== selectors[i].out[0];
        hashers[i].right <== selectors[i].out[1];
    }

    // [assignment] verify that the resultant hash (computed merkle root)
    // is in the set of roots received as input
    // Note that running test.sh should create a valid proof in current circuit, even though it doesn't do anything.
    component isEqual[length + 1];
    var equalSum = 0;

    for (i = 0; i < length; i++) {
        isEqual[i] = IsEqual();

        isEqual[i].in[0] <== hashers[levels - 1].hash;
        isEqual[i].in[1] <== roots[i];

        equalSum += isEqual[i].out;
    }

    isEqual[length] = IsEqual();
    isEqual[length].in[0] <== 1;
    isEqual[length].in[1] <== equalSum;

    ou <== isEqual[length].out;
}

component main = ManyMerkleTreeChecker(2, 2, 3);
