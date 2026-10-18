package com.tududi.tududi.widget

import android.os.Build
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceTheme
import androidx.glance.color.ColorProvider
import androidx.glance.material3.ColorProviders
import androidx.glance.unit.ColorProvider

/**
 * Material You on Android 12+ (`GlanceTheme.colors` follows the wallpaper-derived system palette
 * and the light/dark mode when the views are inflated); on older versions a teal palette seeded
 * like the app (0D9488), light and dark.
 */
private val FallbackColors = ColorProviders(
    light = lightColorScheme(
        primary = Color(0xFF006A62),
        onPrimary = Color(0xFFFFFFFF),
        primaryContainer = Color(0xFF9EF2E6),
        onPrimaryContainer = Color(0xFF00201D),
        surface = Color(0xFFF4FBF9),
        onSurface = Color(0xFF161D1C),
        surfaceVariant = Color(0xFFDAE5E2),
        onSurfaceVariant = Color(0xFF3F4947),
        error = Color(0xFFBA1A1A),
    ),
    dark = darkColorScheme(
        primary = Color(0xFF82D5CB),
        onPrimary = Color(0xFF003732),
        primaryContainer = Color(0xFF005049),
        onPrimaryContainer = Color(0xFF9EF2E6),
        surface = Color(0xFF0E1514),
        onSurface = Color(0xFFDDE4E2),
        surfaceVariant = Color(0xFF3F4947),
        onSurfaceVariant = Color(0xFFBEC9C6),
        error = Color(0xFFFFB4AB),
    ),
)

/** Wraps [content] in the widget theme. */
@Composable
internal fun WidgetTheme(content: @Composable () -> Unit) {
    val colors = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) GlanceTheme.colors else FallbackColors
    GlanceTheme(colors = colors, content = content)
}

/** Semantic colors for the widget; read inside [WidgetTheme]. */
internal object WidgetColors {
    val surface: ColorProvider @Composable get() = GlanceTheme.colors.surface
    val surfaceVariant: ColorProvider @Composable get() = GlanceTheme.colors.surfaceVariant
    val onSurface: ColorProvider @Composable get() = GlanceTheme.colors.onSurface
    val onSurfaceVariant: ColorProvider @Composable get() = GlanceTheme.colors.onSurfaceVariant
    val primary: ColorProvider @Composable get() = GlanceTheme.colors.primary
    val onPrimary: ColorProvider @Composable get() = GlanceTheme.colors.onPrimary
    val primaryContainer: ColorProvider @Composable get() = GlanceTheme.colors.primaryContainer
    val onPrimaryContainer: ColorProvider @Composable get() = GlanceTheme.colors.onPrimaryContainer
    val error: ColorProvider @Composable get() = GlanceTheme.colors.error

    /** Amber for offline/error notices (not part of the Material scheme). Matches the app's warning token. */
    val warning: ColorProvider = ColorProvider(day = Color(0xFF8A5A00), night = Color(0xFFF2B35B))
}

internal object WidgetDimens {
    /** Minimum touch target. */
    val target = 48.dp
    val rowHeight = 52.dp
    val collapsedRowHeight = 22.dp
    val checkbox = 24.dp
    val icon = 22.dp
    val ringLarge = 52.dp
    val ringDense = 44.dp
    val ringCompact = 48.dp
    val fabVisual = 40.dp
    val chipVisual = 32.dp
}

/** Sizes the widget lays itself out for (SizeMode.Responsive picks the biggest that fits). */
internal object WidgetSizes {
    val compact = DpSize(100.dp, 100.dp)
    val medium = DpSize(180.dp, 110.dp)
    val large = DpSize(180.dp, 200.dp)
    val all = setOf(compact, medium, large)

    enum class Layout { COMPACT, MEDIUM, LARGE }

    fun layoutFor(size: DpSize): Layout = when {
        size.width < medium.width -> Layout.COMPACT
        size.height >= large.height -> Layout.LARGE
        else -> Layout.MEDIUM
    }
}
