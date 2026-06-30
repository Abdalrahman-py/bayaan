package com.bayaan

data class MistakeInput(
    val charStart: Int,
    val charEnd: Int,
    val errorType: String,
    val speechErrorType: String?,
    val ruleNameEn: String?,
    val ruleNameAr: String?,
    val expectedLen: Int?,
    val predictedLen: Int?,
)
