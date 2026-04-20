package com.swastricare.health.ui.screens.ai

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * Port of the iOS SceneKit ParticleOrbView to Compose Canvas.
 *
 * Particles live on a unit-sphere shell, projected to 2D each frame,
 * with additive blending for a glow. State drives colour, rotation
 * speed factor, and heartbeat pulse rate — mirroring the iOS variants.
 */
enum class OrbState { Idle, Listening, Thinking }

private data class Particle(
    val theta: Float, // azimuth (0..2pi)
    val phi: Float,   // inclination (0..pi)
    val sizeJitter: Float,
    val alphaJitter: Float,
    val rOff: Float,
    val gOff: Float,
    val bOff: Float
)

private const val PARTICLE_COUNT = 420

@Composable
fun ParticleOrbView(
    state: OrbState,
    isMedicalMode: Boolean = false,
    isDark: Boolean = true,
    modifier: Modifier = Modifier
) {
    val particles = remember {
        val rng = Random(42)
        List(PARTICLE_COUNT) {
            // Uniform distribution on a sphere: phi from acos(1 - 2u)
            val u = rng.nextFloat()
            val v = rng.nextFloat()
            Particle(
                theta = (2f * PI * v).toFloat(),
                phi = kotlin.math.acos(1f - 2f * u),
                sizeJitter = 0.75f + rng.nextFloat() * 0.6f,
                alphaJitter = 0.55f + rng.nextFloat() * 0.45f,
                rOff = (rng.nextFloat() - 0.5f) * 0.4f,
                gOff = (rng.nextFloat() - 0.5f) * 0.4f,
                bOff = (rng.nextFloat() - 0.5f) * 0.4f
            )
        }
    }

    // Palette — dark mode uses additive-glow-friendly low-luminance hues
    // (matches iOS); light mode uses saturated indigo/emerald that stay
    // visible when blended normally on a white background.
    val idleColor: Color
    val activeColor: Color
    val thinkColor: Color
    if (isDark) {
        idleColor = if (isMedicalMode) Color(0xFF0B4D2C) else Color(0xFF1A1F6B)
        activeColor = if (isMedicalMode) Color(0xFF00A86B) else Color(0xFF2E3192)
        thinkColor = if (isMedicalMode) Color(0xFF064A2B) else Color(0xFF0F1345)
    } else {
        idleColor = if (isMedicalMode) Color(0xFF059669) else Color(0xFF4F46E5)
        activeColor = if (isMedicalMode) Color(0xFF10B981) else Color(0xFF6366F1)
        thinkColor = if (isMedicalMode) Color(0xFF047857) else Color(0xFF3730A3)
    }

    val particleColor = when (state) {
        OrbState.Idle -> idleColor
        OrbState.Listening -> activeColor
        OrbState.Thinking -> thinkColor
    }
    val speedFactor = when (state) {
        OrbState.Idle -> 0.5f
        OrbState.Listening -> 2.5f
        OrbState.Thinking -> 2.0f
    }

    // Y-axis rotation (iOS: 8s full turn; speedFactor scales effective rate)
    val rotation = rememberInfiniteTransition(label = "orbRotation")
    val yaw by rotation.animateFloat(
        initialValue = 0f,
        targetValue = (2f * PI).toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween((8000f / speedFactor).toInt(), easing = LinearEasing)
        ),
        label = "orbYaw"
    )

    // Heartbeat pulse — two-beat pattern (lub-dub) scaled by state
    val pulse = rememberInfiniteTransition(label = "orbPulse")
    val (peak1, peak2, cycleMs) = when (state) {
        OrbState.Idle -> Triple(1.08f, 1.06f, 1300)
        OrbState.Listening -> Triple(1.10f, 1.08f, 730)
        OrbState.Thinking -> Triple(1.06f, 1.04f, 1010)
    }
    val scale by pulse.animateFloat(
        initialValue = 1f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = keyframes {
                durationMillis = cycleMs
                1f at 0 using FastOutSlowInEasing
                peak1 at (cycleMs * 0.12f).toInt() using FastOutSlowInEasing
                1f at (cycleMs * 0.19f).toInt() using FastOutSlowInEasing
                peak2 at (cycleMs * 0.31f).toInt() using FastOutSlowInEasing
                1f at (cycleMs * 0.46f).toInt() using LinearEasing
                1f at cycleMs
            }
        ),
        label = "orbScale"
    )

    // Soft breathing alpha so the orb feels alive even at idle
    val alphaBreath by animateFloatAsState(
        targetValue = if (state == OrbState.Idle) 0.9f else 1f,
        animationSpec = tween(400),
        label = "orbAlpha"
    )

    Canvas(modifier = modifier) {
        drawOrb(
            particles = particles,
            yaw = yaw,
            scale = scale,
            baseColor = particleColor,
            globalAlpha = alphaBreath,
            // Additive blend glows on dark backgrounds but washes out to
            // white on light ones, so fall back to normal compositing.
            blendMode = if (isDark) BlendMode.Plus else BlendMode.SrcOver
        )
    }
}

private fun DrawScope.drawOrb(
    particles: List<Particle>,
    yaw: Float,
    scale: Float,
    baseColor: Color,
    globalAlpha: Float,
    blendMode: BlendMode
) {
    val cx = size.width / 2f
    val cy = size.height / 2f
    val radius = min(size.width, size.height) * 0.42f * scale
    val particleBase = radius * 0.018f

    val cosY = cos(yaw)
    val sinY = sin(yaw)

    for (p in particles) {
        // Unit-sphere point
        val sx = sin(p.phi) * cos(p.theta)
        val sy = cos(p.phi)
        val sz = sin(p.phi) * sin(p.theta)

        // Rotate around Y
        val rx = sx * cosY + sz * sinY
        val rz = -sx * sinY + sz * cosY

        // Depth cue: farther points dimmer and smaller
        val depth = (rz + 1f) / 2f // 0 back, 1 front
        val sizeMul = 0.55f + 0.9f * depth
        val alphaMul = 0.35f + 0.65f * depth

        val px = cx + rx * radius
        val py = cy + sy * radius

        val finalAlpha = (alphaMul * p.alphaJitter * globalAlpha).coerceIn(0f, 1f)
        val finalRadius = max(0.5f, particleBase * sizeMul * p.sizeJitter)

        // Per-particle RGB jitter (mirrors iOS particleColorVariation = 0.2)
        val particleColor = Color(
            red = (baseColor.red + p.rOff).coerceIn(0f, 1f),
            green = (baseColor.green + p.gOff).coerceIn(0f, 1f),
            blue = (baseColor.blue + p.bOff).coerceIn(0f, 1f),
            alpha = finalAlpha
        )

        drawCircle(
            color = particleColor,
            radius = finalRadius,
            center = Offset(px, py),
            blendMode = blendMode
        )
    }
}
