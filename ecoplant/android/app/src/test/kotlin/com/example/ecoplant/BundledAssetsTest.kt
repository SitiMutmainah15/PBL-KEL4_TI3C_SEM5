package com.example.ecoplant

import com.google.gson.JsonParser
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BundledAssetsTest {
    private val assets = File("../../assets")
    private val forest by lazy {
        File(assets, "models/forest.json").reader().use {
            JsonParser.parseReader(it).asJsonObject
        }
    }
    private val labels by lazy {
        File(assets, "models/labels.json").reader().use { reader ->
            JsonParser.parseReader(reader).asJsonArray.map { it.asString }
        }
    }

    @Test
    fun TC002_offlineHomeImageIsBundledAsJpeg() {
        assertJpeg(File(assets, "images/banana_leaf.jpg"))
    }

    @Test
    fun TC017_modelAndLabelAssetsAgree() {
        assertEquals(labels, forest["labels"].asJsonArray.map { it.asString })
        assertEquals(64, forest["features"].asInt)
        assertTrue(forest["version"].asString.isNotBlank())
    }

    @Test
    fun TC018_offlineForestHasLocallyTraversableTrees() {
        val trees = forest["trees"].asJsonArray
        assertTrue(trees.size() > 0)
        for (element in trees) {
            val tree = element.asJsonObject
            val features = tree["f"].asJsonArray
            val thresholds = tree["t"].asJsonArray
            val left = tree["l"].asJsonArray
            val right = tree["r"].asJsonArray
            val values = tree["p"].asJsonArray
            assertTrue(features.size() > 0)
            assertTrue(listOf(thresholds, left, right, values).all { it.size() == features.size() })
            for (index in 0 until features.size()) {
                val feature = features[index].asInt
                if (feature >= 0) {
                    assertTrue(feature < forest["features"].asInt)
                    assertTrue(thresholds[index].asDouble.isFinite())
                    assertTrue(left[index].asInt in (index + 1) until features.size())
                    assertTrue(right[index].asInt in (index + 1) until features.size())
                }
            }
        }
    }

    @Test
    fun TC019_modelLabelsSupportFourResultClasses() {
        assertEquals(setOf("Cordana", "Healthy", "Pestalotiopsis", "Sigatoka"), labels.toSet())
        assertEquals(4, labels.size)
    }

    @Test
    fun TC021_leafConfidenceInputsAreBounded() {
        for (element in forest["trees"].asJsonArray) {
            val tree = element.asJsonObject
            for ((index, feature) in tree["f"].asJsonArray.withIndex()) {
                if (feature.asInt >= 0) continue
                val scores = tree["p"].asJsonArray[index].asJsonArray.map { it.asDouble }
                assertEquals(labels.size, scores.size)
                assertTrue(scores.all { it.isFinite() && it in 0.0..1.0 })
                assertEquals(1.0, scores.sum(), 0.0001)
            }
        }
    }

    @Test
    fun TC031_eachResultClassHasThreeBundledJpegReferences() {
        for (label in labels) {
            val photos = File(assets, "references/${label.lowercase()}")
                .listFiles { file -> file.extension == "jpg" }.orEmpty()
            assertEquals(label, 3, photos.size)
            photos.forEach(::assertJpeg)
        }
    }

    private fun assertJpeg(file: File) {
        val bytes = file.readBytes()
        assertTrue("Truncated JPEG: $file", bytes.size > 4)
        assertEquals("JPEG start: $file", listOf(-1, -40), bytes.take(2).map { it.toInt() })
        assertEquals("JPEG end: $file", listOf(-1, -39), bytes.takeLast(2).map { it.toInt() })
    }
}
