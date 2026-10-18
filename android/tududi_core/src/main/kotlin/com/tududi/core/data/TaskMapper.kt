package com.tududi.core.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.intOrNull
import java.time.LocalDate

/**
 * Maps the response of `GET /api/tasks?type=today&include_lists=true` into a [TodayBoard].
 *
 * Tududi returns `tasks` plus optional helper lists (`tasks_overdue`, `tasks_due_today`,
 * `tasks_today_plan`, `tasks_in_progress`, `tasks_completed_today`). Status may be a number
 * or a string depending on server version, and `due_date` may be a date or an ISO timestamp.
 * `original_name` (the title as typed, before the server strips parsed tokens) wins over `name`.
 */
object TaskMapper {
    private val json = Json { ignoreUnknownKeys = true }

    private val OPEN_LISTS = listOf("tasks", "tasks_today_plan", "tasks_due_today", "tasks_in_progress", "tasks_overdue")

    fun parseBoard(body: String, today: LocalDate): TodayBoard {
        val root = json.parseToJsonElement(body) as? JsonObject
            ?: throw IllegalArgumentException("Expected a JSON object")
        if (root["tasks"] !is JsonArray) throw IllegalArgumentException("Response has no tasks array")

        val seen = LinkedHashMap<String, TodoTask>()
        for (key in OPEN_LISTS + "tasks_completed_today") {
            (root[key] as? JsonArray)?.forEach { el ->
                parseTask(el)?.let { t -> seen.putIfAbsent(t.uid, t) }
            }
        }
        val all = seen.values.filterNot { it.isClosed }
        val open = all.filterNot { it.isDone }.sortedWith(openOrder(today))
        return TodayBoard(
            open = open,
            overdue = open.filter { it.isOverdue(today) },
            done = all.filter { it.isDone }.sortedBy { it.name.lowercase() },
        )
    }

    private fun openOrder(today: LocalDate) = compareBy<TodoTask>(
        { if (it.isOverdue(today)) 0 else 1 },
        { it.dueDate ?: LocalDate.MAX },
        { -it.priority },
        { it.name.lowercase() },
    )

    fun parseTask(el: JsonElement): TodoTask? {
        val o = el as? JsonObject ?: return null
        val uid = o.string("uid") ?: o.string("id") ?: return null
        val name = o.string("original_name")?.takeIf { it.isNotBlank() }
            ?: o.string("name")?.takeIf { it.isNotBlank() }
            ?: return null
        return TodoTask(
            uid = uid,
            name = name,
            status = parseStatus(o["status"]),
            dueDate = parseDate(o.string("due_date")),
            projectName = (o["Project"] as? JsonObject)?.string("name")
                ?: (o["project"] as? JsonObject)?.string("name"),
            priority = parsePriority(o["priority"]),
        )
    }

    fun parseStatus(el: JsonElement?): TaskStatus {
        val p = el as? JsonPrimitive ?: return TaskStatus.NOT_STARTED
        return p.intOrNull?.let(TaskStatus::fromCode) ?: TaskStatus.fromName(p.content)
    }

    fun parseDate(raw: String?): LocalDate? {
        if (raw.isNullOrBlank() || raw.length < 10) return null
        return runCatching { LocalDate.parse(raw.substring(0, 10)) }.getOrNull()
    }

    private fun parsePriority(el: JsonElement?): Int {
        val p = el as? JsonPrimitive ?: return 0
        return p.intOrNull ?: when (p.content.lowercase()) {
            "high" -> 2
            "medium" -> 1
            else -> 0
        }
    }

    private fun JsonObject.string(key: String): String? {
        val v = this[key]
        if (v == null || v is JsonNull) return null
        return (v as? JsonPrimitive)?.content
    }
}
