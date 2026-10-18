package com.tududi.core.data

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Short due-date label: the localized "today" word, or e.g. "16 Oct" / "16. Okt.". */
fun dueLabel(date: LocalDate?, today: LocalDate, todayWord: String, locale: Locale = Locale.getDefault()): String? {
    if (date == null) return null
    if (date == today) return todayWord
    val pattern = if (date.year == today.year) "d MMM" else "d MMM yyyy"
    return date.format(DateTimeFormatter.ofPattern(pattern, locale))
}
