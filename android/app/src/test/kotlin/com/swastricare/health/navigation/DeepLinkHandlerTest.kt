package com.swastricare.health.navigation

import android.net.Uri
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.*
import org.junit.Test

class DeepLinkHandlerTest {

    private fun mockUri(
        scheme: String?,
        host: String?,
        pathSegments: List<String> = emptyList(),
        queryParams: Map<String, String?> = emptyMap()
    ): Uri = mockk {
        every { getScheme() } returns scheme
        every { this@mockk.scheme } returns scheme
        every { getHost() } returns host
        every { this@mockk.host } returns host
        every { this@mockk.pathSegments } returns pathSegments
        for ((key, value) in queryParams) {
            every { getQueryParameter(key) } returns value
        }
        if (queryParams.isEmpty()) {
            every { getQueryParameter(any()) } returns null
        }
    }

    // ── Null / unsupported scheme ──

    @Test
    fun `parse returns null for null uri`() {
        assertNull(DeepLinkHandler.parse(null))
    }

    @Test
    fun `parse returns null for unsupported scheme`() {
        val uri = mockUri(scheme = "https", host = "home")
        assertNull(DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse returns null for auth-callback host`() {
        val uri = mockUri(scheme = "swastricare", host = "auth-callback")
        assertNull(DeepLinkHandler.parse(uri))
    }

    // ── Basic routes ──

    @Test
    fun `parse home route`() {
        val uri = mockUri(scheme = "swastricare", host = "home")
        assertEquals(DeepLinkRoute.Home, DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse hydration route`() {
        val uri = mockUri(scheme = "swastricareapp", host = "hydration")
        assertEquals(DeepLinkRoute.Hydration, DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse medications route`() {
        val uri = mockUri(scheme = "swastricare", host = "medications")
        assertEquals(DeepLinkRoute.Medications, DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse heartrate route`() {
        val uri = mockUri(scheme = "swastricare", host = "heartrate")
        assertEquals(DeepLinkRoute.HeartRate, DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse steps route`() {
        val uri = mockUri(scheme = "swastricare", host = "steps")
        assertEquals(DeepLinkRoute.Steps, DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse diet route`() {
        val uri = mockUri(scheme = "swastricare", host = "diet")
        assertEquals(DeepLinkRoute.Diet, DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse vault route`() {
        val uri = mockUri(scheme = "swastricare", host = "vault")
        assertEquals(DeepLinkRoute.Vault, DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse ai route`() {
        val uri = mockUri(scheme = "swastricare", host = "ai")
        assertEquals(DeepLinkRoute.AI, DeepLinkHandler.parse(uri))
    }

    // ── Run routes ──

    @Test
    fun `parse run route without path`() {
        val uri = mockUri(scheme = "swastricare", host = "run")
        assertEquals(DeepLinkRoute.Run, DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse run start with type query param`() {
        val uri = mockUri(
            scheme = "swastricare",
            host = "run",
            pathSegments = listOf("start"),
            queryParams = mapOf("type" to "walk")
        )
        assertEquals(DeepLinkRoute.StartRun("walk"), DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse run start defaults to run type when no query param`() {
        val uri = mockUri(
            scheme = "swastricare",
            host = "run",
            pathSegments = listOf("start")
        )
        assertEquals(DeepLinkRoute.StartRun("run"), DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse activeworkout defaults to run`() {
        val uri = mockUri(scheme = "swastricare", host = "activeworkout")
        assertEquals(DeepLinkRoute.StartRun("run"), DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse startrun with path segment type`() {
        val uri = mockUri(
            scheme = "swastricare",
            host = "startrun",
            pathSegments = listOf("cycle")
        )
        assertEquals(DeepLinkRoute.StartRun("cycle"), DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse startrun with query param type`() {
        val uri = mockUri(
            scheme = "swastricare",
            host = "startrun",
            queryParams = mapOf("type" to "hike")
        )
        assertEquals(DeepLinkRoute.StartRun("hike"), DeepLinkHandler.parse(uri))
    }

    // ── Family routes ──

    @Test
    fun `parse family join with valid 6-char code`() {
        val uri = mockUri(
            scheme = "swastricare",
            host = "family",
            pathSegments = listOf("join"),
            queryParams = mapOf("code" to "ABC123")
        )
        assertEquals(DeepLinkRoute.FamilyJoin("ABC123"), DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse family join with invalid code returns Unknown`() {
        val uri = mockUri(
            scheme = "swastricare",
            host = "family",
            pathSegments = listOf("join"),
            queryParams = mapOf("code" to "AB") // too short
        )
        assertEquals(DeepLinkRoute.Unknown, DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse family join with no code returns Unknown`() {
        val uri = mockUri(
            scheme = "swastricare",
            host = "family",
            pathSegments = listOf("join")
        )
        assertEquals(DeepLinkRoute.Unknown, DeepLinkHandler.parse(uri))
    }

    @Test
    fun `parse family without join path returns Unknown`() {
        val uri = mockUri(scheme = "swastricare", host = "family")
        assertEquals(DeepLinkRoute.Unknown, DeepLinkHandler.parse(uri))
    }

    // ── Unknown routes ──

    @Test
    fun `parse unknown host returns Unknown`() {
        val uri = mockUri(scheme = "swastricare", host = "nonexistent")
        assertEquals(DeepLinkRoute.Unknown, DeepLinkHandler.parse(uri))
    }

    // ── toNavRoute ──

    @Test
    fun `toNavRoute maps Home to vitals`() {
        assertEquals("vitals", DeepLinkHandler.toNavRoute(DeepLinkRoute.Home))
    }

    @Test
    fun `toNavRoute maps Hydration`() {
        assertEquals("hydration", DeepLinkHandler.toNavRoute(DeepLinkRoute.Hydration))
    }

    @Test
    fun `toNavRoute maps Medications`() {
        assertEquals("medications", DeepLinkHandler.toNavRoute(DeepLinkRoute.Medications))
    }

    @Test
    fun `toNavRoute maps HeartRate`() {
        assertEquals("heart_rate", DeepLinkHandler.toNavRoute(DeepLinkRoute.HeartRate))
    }

    @Test
    fun `toNavRoute maps Steps`() {
        assertEquals("steps", DeepLinkHandler.toNavRoute(DeepLinkRoute.Steps))
    }

    @Test
    fun `toNavRoute maps Run to steps`() {
        assertEquals("steps", DeepLinkHandler.toNavRoute(DeepLinkRoute.Run))
    }

    @Test
    fun `toNavRoute maps StartRun with type`() {
        assertEquals("live_workout?type=walk", DeepLinkHandler.toNavRoute(DeepLinkRoute.StartRun("walk")))
    }

    @Test
    fun `toNavRoute maps Diet`() {
        assertEquals("diet", DeepLinkHandler.toNavRoute(DeepLinkRoute.Diet))
    }

    @Test
    fun `toNavRoute maps Vault`() {
        assertEquals("vault", DeepLinkHandler.toNavRoute(DeepLinkRoute.Vault))
    }

    @Test
    fun `toNavRoute maps AI`() {
        assertEquals("ai", DeepLinkHandler.toNavRoute(DeepLinkRoute.AI))
    }

    @Test
    fun `toNavRoute maps FamilyJoin with code`() {
        assertEquals("family_join/ABC123", DeepLinkHandler.toNavRoute(DeepLinkRoute.FamilyJoin("ABC123")))
    }

    @Test
    fun `toNavRoute maps Unknown to vitals`() {
        assertEquals("vitals", DeepLinkHandler.toNavRoute(DeepLinkRoute.Unknown))
    }

    // ── Both schemes supported ──

    @Test
    fun `both swastricare and swastricareapp schemes are supported`() {
        val uri1 = mockUri(scheme = "swastricare", host = "home")
        val uri2 = mockUri(scheme = "swastricareapp", host = "home")
        assertEquals(DeepLinkRoute.Home, DeepLinkHandler.parse(uri1))
        assertEquals(DeepLinkRoute.Home, DeepLinkHandler.parse(uri2))
    }
}
