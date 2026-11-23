package com.example.ecoplant

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Document
import org.w3c.dom.Element

class ManifestTest {
    private val androidNamespace = "http://schemas.android.com/apk/res/android"
    private val manifest: Document = DocumentBuilderFactory.newInstance().apply {
        isNamespaceAware = true
    }.newDocumentBuilder().parse(File("src/main/AndroidManifest.xml"))

    private fun androidAttribute(tag: String, name: String, attribute: String): String? {
        val elements = manifest.getElementsByTagName(tag)
        return (0 until elements.length)
            .map { elements.item(it) as Element }
            .firstOrNull { it.getAttributeNS(androidNamespace, "name") == name }
            ?.getAttributeNS(androidNamespace, attribute)
    }

    @Test
    fun `TS-003 TC-006 and TS-004 TC-009 - declares runtime camera permission`() {
        val permission = "android.permission.CAMERA"
        assertEquals(permission, androidAttribute("uses-permission", permission, "name"))
    }

    @Test
    fun `TS-003 TC-006 - camera hardware stays optional at install time`() {
        assertEquals("false", androidAttribute("uses-feature", "android.hardware.camera", "required"))
    }

    @Test
    fun `TS-001 TC-001 - uses Flutter embedding version two`() {
        assertEquals("2", androidAttribute("meta-data", "flutterEmbedding", "value"))
    }

    @Test
    fun `TS-003 TC-008 - foreground relaunch reuses the top Android activity`() {
        assertEquals("singleTop", androidAttribute("activity", ".MainActivity", "launchMode"))
    }

    @Test
    fun `TS-001 TC-001 - exports MainActivity as the Android launcher`() {
        assertEquals("true", androidAttribute("activity", ".MainActivity", "exported"))
        val filters = manifest.getElementsByTagName("intent-filter")
        assertTrue((0 until filters.length).any { index ->
            val filter = filters.item(index) as Element
            val parent = filter.parentNode as Element
            parent.getAttributeNS(androidNamespace, "name") == ".MainActivity" &&
                filter.getElementsByTagName("action").item(0)
                    ?.attributes?.getNamedItemNS(androidNamespace, "name")?.nodeValue ==
                "android.intent.action.MAIN" &&
                filter.getElementsByTagName("category").item(0)
                    ?.attributes?.getNamedItemNS(androidNamespace, "name")?.nodeValue ==
                "android.intent.category.LAUNCHER"
        })
    }
}
