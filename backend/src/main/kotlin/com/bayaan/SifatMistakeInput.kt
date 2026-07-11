package com.bayaan

// One sifat (pronunciation-attribute) mismatch from the engine's `sifat_errors` array.
// Mirrors MistakeInput; persisted via SifatMistakeRepository into the sifat_mistakes table.
data class SifatMistakeInput(
    val phonemesGroup: String,
    val attribute: String,
    val predicted: String,
    val expected: String,
    val confidence: Double?,
)
