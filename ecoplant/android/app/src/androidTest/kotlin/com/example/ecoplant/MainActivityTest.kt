package com.example.ecoplant

import android.Manifest
import android.app.KeyguardManager
import android.content.pm.PackageManager
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.graphics.Rect
import android.view.accessibility.AccessibilityNodeInfo
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.isAssignableFrom
import androidx.test.espresso.matcher.ViewMatchers.isDisplayed
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry
import androidx.test.runner.lifecycle.Stage
import io.flutter.embedding.android.FlutterView
import org.junit.After
import org.junit.Before
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainActivityTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()

    @Before
    fun launchFromForeground() {
        val keyguard = instrumentation.targetContext.getSystemService(KeyguardManager::class.java)
        assumeTrue("Unlock the Android test device before opening EcoPlant", !keyguard.isKeyguardLocked)
        // Launch as a foreground Android shell action on devices that restrict background starts.
        val component = "${instrumentation.targetContext.packageName}/.MainActivity"
        val output = runShell("am start -W -n $component")
        assertTrue(output, output.contains("Status: ok"))
        runShell("cmd statusbar collapse")
    }

    @After
    fun finishActivity() {
        instrumentation.runOnMainSync {
            ActivityLifecycleMonitorRegistry.getInstance().getActivitiesInStage(Stage.RESUMED)
                .filterIsInstance<MainActivity>()
                .forEach { it.finish() }
        }
        instrumentation.waitForIdleSync()
    }

    @Test
    fun TS001_TC001_launchShowsHomeAndAllTabs() {
        onView(isAssignableFrom(FlutterView::class.java)).check(matches(isDisplayed()))
        awaitLabel("Scan Daun")
        awaitLabel("Beranda", tab = true)
        awaitLabel("Scan", tab = true)
        awaitLabel("Riwayat", tab = true)
    }

    @Test
    fun TS002_TC003_scanDaunOpensScan() {
        tapLabel("Scan Daun")
        awaitLabel("Mulai dari satu daun.")
        awaitLabel("Buka Kamera")
    }

    @Test
    fun TS002_TC004_riwayatTabOpensHistory() {
        tapLabel("Riwayat", tab = true)
        awaitLabel("Pemeriksaan daun Anda")
    }

    @Test
    fun TS002_TC005_lihatSemuaOpensHistory() {
        awaitLabel("Scan Daun")
        if (findLabel("Lihat semua") == null) scrollContent()
        tapLabel("Lihat semua")
        awaitLabel("Pemeriksaan daun Anda")
    }

    @Test
    fun TS008_TC015_scanWithoutPhotoHasNoAnalyzeAction() {
        tapLabel("Scan Daun")
        awaitLabel("Belum ada foto dipilih.", prefix = true)
        awaitLabel("Pilih dari Galeri")
        assertTrue(findLabel("Analisis") == null)
    }

    @Test
    fun TS011_TC026_emptyHistoryCanStartScan() {
        tapLabel("Riwayat", tab = true)
        awaitLabel("Pemeriksaan daun Anda")
        assumeTrue("TC-026 requires an empty history database", findLabel("Hapus riwayat", prefix = true) == null)
        awaitLabel("Belum ada hasil deteksi.", prefix = true)
        tapLabel("Scan daun pertama")
        awaitLabel("Mulai dari satu daun.")
    }

    @Test
    fun TS015_TC036_helpdeskShowsAllQuestionsAndReturnsHome() {
        tapLabel("Helpdesk")
        awaitLabel("Pertanyaan umum")
        for (question in listOf(
            "Bagaimana cara memindai daun?",
            "Kenapa kamera atau galeri tidak terbuka?",
            "Di mana hasil pemindaian sebelumnya?",
        )) {
            tapLabel(question, prefix = true)
            tapLabel(question, prefix = true)
        }
        runShell("input keyevent 4")
        awaitLabel("Scan Daun")
    }

    @Test
    fun TS016_TC037_blankDescriptionShowsValidation() {
        tapLabel("Helpdesk")
        awaitLabel("Pertanyaan umum")
        scrollContent()
        tapLabel("Kirim Email")
        awaitLabel("Isi deskripsi kendala.")
        awaitLabel("Kirim Email")
    }

    @Test
    fun TS016_TC037_whitespaceDescriptionShowsValidation() {
        tapLabel("Helpdesk")
        awaitLabel("Pertanyaan umum")
        scrollContent()
        enterDescription("%s%s")
        tapLabel("Kirim Email")
        awaitLabel("Isi deskripsi kendala.")
    }

    @Test
    fun TS001_TC002_offlineLaunchOpensLocalHistory() {
        requireScenario("offline")
        assumeTrue("Enable airplane mode before running TC-002",
            runShell("settings get global airplane_mode_on").trim() == "1")
        awaitLabel("Scan Daun")
        tapLabel("Riwayat", tab = true)
        awaitLabel("Pemeriksaan daun Anda")
        assertTrue(findLabel("Riwayat gagal dimuat.", prefix = true) == null)
    }

    @Test
    fun TS003_TC006_acceptingCameraPermissionEnablesCapture() {
        requireScenario("camera-allow")
        assumeTrue("Reset camera permission before TC-006", !cameraGranted())
        openCamera()
        tapPermissionButton("permission_allow_foreground_only_button")
        awaitCaptureEnabled()
    }

    @Test
    fun TS003_TC007_captureReturnsPhotoPreview() {
        requireScenario("camera-capture")
        assumeTrue("Grant camera permission and aim the phone at a test leaf", cameraGranted())
        openCamera()
        awaitCaptureEnabled()
        tapLabel("Ambil Foto", clickable = true)
        awaitLabel("Periksa foto Anda")
        awaitLabel("Analisis")
    }

    @Test
    fun TS003_TC008_cameraResumesAfterGoingHome() {
        requireScenario("camera-capture")
        assumeTrue("Grant camera permission and aim the phone at a test leaf", cameraGranted())
        openCamera()
        awaitCaptureEnabled()
        runShell("input keyevent 3")
        launchFromForeground()
        awaitCaptureEnabled()
        tapLabel("Ambil Foto", clickable = true)
        awaitLabel("Periksa foto Anda")
    }

    @Test
    fun TS004_TC009_deniedCameraPermissionLeavesReturnAction() {
        requireScenario("camera-deny")
        assumeTrue("Reset camera permission before TC-009", !cameraGranted())
        openCamera()
        tapPermissionButton("permission_deny_button", "permission_deny_and_dont_ask_again_button")
        awaitLabel("Izin kamera belum diberikan.", prefix = true)
        val action = findLabel("Ambil Foto", clickable = true)
        assertTrue(action == null || !action.isEnabled)
        tapLabel("Kembali ke Scan")
        awaitLabel("Mulai dari satu daun.")
    }

    @Test
    fun TS005_TC010_androidPickerReturnsPreparedPhoto() {
        requireScenario("gallery")
        val pickerLabel = InstrumentationRegistry.getArguments().getString("tctsPickerLabel")
        assumeTrue("Provide the full accessibility label of a prepared JPEG or PNG",
            !pickerLabel.isNullOrBlank())
        tapLabel("Scan Daun")
        tapLabel("Pilih dari Galeri")
        tapLabel(requireNotNull(pickerLabel))
        awaitLabel("Periksa foto Anda")
        awaitLabel("Analisis")
    }

    @Test
    fun TS016_TC039_deviceWithoutMailAppKeepsDescription() {
        requireScenario("no-email-app")
        val handler = runShell("cmd package resolve-activity --brief -a android.intent.action.VIEW -d mailto:qa@example.invalid")
        assumeTrue("Use a test device with no registered mailto handler", handler.contains("No activity found"))
        tapLabel("Helpdesk")
        awaitLabel("Pertanyaan umum")
        scrollContent()
        enterDescription("Kamera%stidak%sterbuka")
        tapLabel("Kirim Email")
        awaitLabel("Aplikasi email tidak dapat dibuka.", prefix = true)
        awaitLabel("Kamera tidak terbuka", prefix = true)
        awaitLabel("Kirim Email")
    }

    @Test
    fun TS016_TC038_emailClientOpensPreparedDraft() {
        requireScenario("email-draft")
        tapLabel("Helpdesk")
        awaitLabel("Pertanyaan umum")
        scrollContent()
        tapLabel("Scan daun", prefix = true, clickable = true)
        tapLabel("Riwayat", clickable = true)
        enterDescription("Riwayat%stidak%stampil")
        tapLabel("Kirim Email")
        awaitLabel("fatahaidaraly@gmail.com", prefix = true)
        awaitLabel("Laporan kendala EcoPlant AI", prefix = true)
        awaitLabel("Kategori: Riwayat", prefix = true)
        awaitLabel("Riwayat tidak tampil", prefix = true)
        runShell("input keyevent 4")
    }

    @Test
    fun recreationDisplaysFlutterViewAgain() {
        val original = awaitResumedActivity()
        instrumentation.runOnMainSync { original.recreate() }
        awaitResumedActivity(previous = original)
        onView(isAssignableFrom(FlutterView::class.java)).check(matches(isDisplayed()))
    }

    private fun runShell(command: String): String =
        ParcelFileDescriptor.AutoCloseInputStream(
            instrumentation.uiAutomation.executeShellCommand(command)
        ).bufferedReader().use { it.readText() }

    private fun requireScenario(scenario: String) {
        assumeTrue("Use -e tctsScenario $scenario on a prepared device",
            InstrumentationRegistry.getArguments().getString("tctsScenario") == scenario)
    }

    private fun cameraGranted() = instrumentation.targetContext
        .checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    private fun openCamera() {
        tapLabel("Scan Daun")
        tapLabel("Buka Kamera")
    }

    private fun awaitCaptureEnabled() {
        val deadline = SystemClock.uptimeMillis() + 12_000
        do {
            if (findLabel("Ambil Foto", clickable = true)?.isEnabled == true) return
            SystemClock.sleep(150)
        } while (SystemClock.uptimeMillis() < deadline)
        throw AssertionError("Camera capture action stayed disabled")
    }

    private fun tapPermissionButton(vararg ids: String) {
        val deadline = SystemClock.uptimeMillis() + 12_000
        do {
            val root = instrumentation.uiAutomation.rootInActiveWindow
            for (packageName in listOf("com.android.permissioncontroller", "com.google.android.permissioncontroller")) {
                for (id in ids) {
                    val button = root?.findAccessibilityNodeInfosByViewId("$packageName:id/$id")
                        ?.firstOrNull { it.isVisibleToUser }
                    if (button?.performAction(AccessibilityNodeInfo.ACTION_CLICK) == true) return
                }
            }
            SystemClock.sleep(150)
        } while (SystemClock.uptimeMillis() < deadline)
        throw AssertionError("Android permission dialog button not found: ${ids.joinToString()}")
    }

    private fun scrollContent() {
        val bounds = Rect()
        instrumentation.uiAutomation.rootInActiveWindow.getBoundsInScreen(bounds)
        runShell("input swipe ${bounds.centerX()} ${bounds.bottom * 4 / 5} ${bounds.centerX()} ${bounds.bottom / 3} 300")
    }

    private fun enterDescription(text: String) {
        val bounds = Rect()
        awaitLabel("", prefix = true, editable = true).getBoundsInScreen(bounds)
        runShell("input tap ${bounds.centerX()} ${bounds.centerY()}")
        runShell("input text $text")
        runShell("input keyevent 4")
    }

    private fun tapLabel(label: String, tab: Boolean = false, prefix: Boolean = false, clickable: Boolean = false) {
        val node = awaitLabel(label, tab, prefix, clickable)
        if (!node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
            val bounds = Rect()
            node.getBoundsInScreen(bounds)
            runShell("input tap ${bounds.centerX()} ${bounds.centerY()}")
        }
    }

    private fun findLabel(label: String, tab: Boolean = false, prefix: Boolean = false,
                          clickable: Boolean = false, editable: Boolean = false): AccessibilityNodeInfo? {
        val automation = instrumentation.uiAutomation
        fun find(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
            val name = (node.contentDescription ?: node.text)?.toString().orEmpty()
            if (node.isVisibleToUser && (!clickable || node.isClickable) &&
                    (!editable || node.isEditable) && (name == label ||
                    tab && name.startsWith("$label\nTab ") ||
                    prefix && name.contains(label))) {
                return node
            }
            for (index in 0 until node.childCount) {
                val child = node.getChild(index) ?: continue
                find(child)?.let { return it }
            }
            return null
        }
        return automation.rootInActiveWindow?.let(::find)
    }

    private fun awaitLabel(label: String, tab: Boolean = false, prefix: Boolean = false,
                           clickable: Boolean = false, editable: Boolean = false): AccessibilityNodeInfo {
        val deadline = SystemClock.uptimeMillis() + 12_000
        do {
            findLabel(label, tab, prefix, clickable, editable)?.let { return it }
            SystemClock.sleep(150)
        } while (SystemClock.uptimeMillis() < deadline)
        throw AssertionError("Visible label not found: $label")
    }

    private fun awaitResumedActivity(previous: MainActivity? = null): MainActivity {
        val deadline = SystemClock.uptimeMillis() + 10_000
        do {
            var resumed: MainActivity? = null
            instrumentation.runOnMainSync {
                resumed = ActivityLifecycleMonitorRegistry.getInstance()
                    .getActivitiesInStage(Stage.RESUMED)
                    .filterIsInstance<MainActivity>()
                    .firstOrNull { it !== previous }
            }
            resumed?.let { return it }
            SystemClock.sleep(100)
        } while (SystemClock.uptimeMillis() < deadline)
        throw AssertionError("MainActivity did not reach RESUMED within 10 seconds")
    }
}
