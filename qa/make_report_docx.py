"""Membuat laporan integration test dalam format Word dari isi yang sama
dengan qa/integration-test-report.html."""

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

GREEN = RGBColor(0x2F, 0x4A, 0x22)
GREY = RGBColor(0x5A, 0x6B, 0x52)
OK = RGBColor(0x2F, 0x7A, 0x24)

SCENARIOS = [
    ("Splash ke beranda.",
     "Teks \u201cEcoPlant\u201d tampil, setelah 3 detik aplikasi masuk ke beranda dan menampilkan keadaan riwayat kosong."),
    ("Pilih foto, analisis, simpan riwayat.",
     "\u201cScan Daun\u201d membuka tab scan, \u201cPilih dari Galeri\u201d memuat foto, \u201cAnalisis\u201d membuka layar hasil (Sigatoka, confidence 92,0%), \u201cSimpan Riwayat\u201d menulis ke repositori."),
    ("Riwayat dan detailnya.",
     "Tab \u201cRiwayat\u201d menampilkan \u201cConfidence 92.0%\u201d; menekan item membuka layar \u201cDetail Riwayat\u201d."),
    ("Keterangan kondisi tampil.",
     "Blok \u201cTentang kondisi ini\u201d, \u201cPenanganan awal\u201d, \u201cFoto pembanding\u201d, dan kartu \u201cSaran foto berikutnya\u201d muncul di layar hasil."),
    ("Keterangan tidak diminta ulang.",
     "Buka hasil, kembali, lalu analisis lagi: layanan tetap dipanggil satu kali (CaptionCache bekerja)."),
    ("Keterangan gagal.",
     "Pesan kegagalan tampil, tombol \u201cTampilkan keterangan umum\u201d menampilkan teks cadangan Sigatoka (kondisi dan penanganan)."),
    ("Coba lagi setelah gagal.",
     "Kegagalan pertama tidak disimpan di cache; menekan \u201cCoba Lagi\u201d memanggil ulang layanan dan ringkasan berhasil tampil."),
    ("Label model bahasa berbeda.",
     "Label \u201cCordana\u201d dari model bahasa pada hasil Sigatoka memunculkan penjelasan bahwa label model gambar tetap dipakai."),
    ("Foto sulit dibaca.",
     "Nilai gambarSesuai: false mengubah judul kartu menjadi \u201cFoto ini sulit dibaca\u201d dan menyembunyikan judul saran foto."),
    ("Galeri gagal dibuka.",
     "Pesan izin foto tampil, layar tetap pada keadaan awal, dan tombol \u201cBuka Kamera\u201d aktif kembali."),
    ("Berkas bukan gambar.",
     "Memilih berkas teks ditolak validator gambar asli dengan pesan format JPEG/PNG; foto tidak dipakai."),
    ("Batalkan foto.",
     "Setelah foto terpilih, \u201cBatalkan Foto\u201d mengembalikan layar ke \u201cMulai dari satu daun.\u201d dan \u201cBelum ada foto dipilih.\u201d"),
    ("Scan ulang.",
     "Dari layar hasil, \u201cScan Ulang\u201d menutup layar dan mengosongkan pilihan foto sebelumnya."),
]

META = [
    ("Tanggal", "6 November 2026"),
    ("Aplikasi", "ecoplant (Flutter 3.41.9, Dart 3.11.5)"),
    ("Perangkat", "Samsung SM A146P \u2014 Android 15 (API 35), arm64"),
    ("Jenis uji", "Integration test (aplikasi berjalan di perangkat, bukan widget test)"),
    ("Berkas uji", "ecoplant/integration_test/app_test.dart"),
    ("Perintah", "flutter test integration_test/app_test.dart -d R9CW303CT9V"),
    ("Durasi", "Build 19,1 s \u00b7 install 4,0 s \u00b7 eksekusi 91 s"),
    ("Hasil", "All tests passed! (13 lulus, 0 gagal)"),
]

PROVIDERS = [
    ("historyRepositoryProvider", "Penyimpanan di memori"),
    ("galleryServiceProvider", "Path berkas buatan; satu kasus memakai galeri yang menolak dibuka"),
    ("detectionServiceProvider", "Hasil deteksi tetap (Sigatoka, 0,92)"),
    ("captionServiceProvider", "Teks tetap, dapat disetel gagal atau beda label"),
]

LOG = """00:00 +0: loading C:/PBL-KEL4_TI3C_SEM5/ecoplant/integration_test/app_test.dart
Running Gradle task 'assembleDebug'...                             19.1s
\u221a Built build\\app\\outputs\\flutter-apk\\app-debug.apk
Installing build\\app\\outputs\\flutter-apk\\app-debug.apk...           4.0s
00:00 +0: (setUpAll)
00:00 +0: 1. splash tampil lalu berpindah ke beranda
00:09 +1: 2. pilih foto, analisis, lalu simpan ke riwayat
00:16 +2: 3. riwayat menampilkan hasil tersimpan dan detailnya
00:22 +3: 4. keterangan kondisi tampil di layar hasil
00:29 +4: 5. keterangan tidak diminta ulang untuk hasil yang sama
00:37 +5: 6. keterangan gagal menyediakan keterangan umum
00:44 +6: 7. coba lagi memuat keterangan setelah gagal
00:51 +7: 8. label model bahasa yang berbeda diberi penjelasan
00:57 +8: 9. foto yang dinilai sulit dibaca memakai judul khusus
01:04 +9: 10. galeri gagal dibuka menampilkan pesan izin
01:10 +10: 11. berkas yang bukan gambar ditolak
01:16 +11: 12. batalkan foto mengosongkan pilihan
01:23 +12: 13. scan ulang mengosongkan hasil sebelumnya
01:31 +13: (tearDownAll)
01:32 +13: All tests passed!"""


def shade(cell, hex_color):
    element = OxmlElement("w:shd")
    element.set(qn("w:val"), "clear")
    element.set(qn("w:fill"), hex_color)
    cell._tc.get_or_add_tcPr().append(element)


def keep_together(grid):
    """Baris tabel tidak terpotong di antara dua halaman."""
    for row in grid.rows:
        tr_pr = row._tr.get_or_add_trPr()
        tr_pr.append(OxmlElement("w:cantSplit"))


def table(doc, rows, widths, bold_first=False):
    grid = doc.add_table(rows=0, cols=len(widths))
    grid.style = "Table Grid"
    grid.alignment = WD_TABLE_ALIGNMENT.CENTER
    grid.autofit = False
    for values in rows:
        cells = grid.add_row().cells
        for cell, value, width in zip(cells, values, widths):
            cell.width = Cm(width)
            paragraph = cell.paragraphs[0]
            paragraph.paragraph_format.space_after = Pt(2)
            paragraph.add_run(value).font.size = Pt(9)
            if bold_first and values is rows[0]:
                shade(cell, "F1F7EC")
                paragraph.runs[0].bold = True
    return grid


doc = Document()
section = doc.sections[0]
section.page_width, section.page_height = Cm(21), Cm(29.7)
section.left_margin = section.right_margin = Cm(1.6)
section.top_margin = section.bottom_margin = Cm(1.6)

normal = doc.styles["Normal"]
normal.font.name = "Segoe UI"
normal.font.size = Pt(10)
normal.paragraph_format.space_after = Pt(4)

heading = doc.add_paragraph()
run = heading.add_run("Laporan Integration Test \u2014 EcoPlant AI")
run.bold = True
run.font.size = Pt(19)
run.font.color.rgb = GREEN

sub = doc.add_paragraph()
run = sub.add_run("Flutter integration test pada perangkat Android fisik")
run.font.size = Pt(10)
run.font.color.rgb = GREY

badge = doc.add_paragraph()
run = badge.add_run(" 13 / 13 test lulus ")
run.bold = True
run.font.size = Pt(10)
run.font.color.rgb = GREEN

paragraph = doc.add_paragraph()
run = paragraph.add_run("Informasi Pengujian")
run.bold = True
run.font.size = Pt(12)
run.font.color.rgb = GREEN

keep_together(table(doc, [("Komponen", "Keterangan")] + META, [4.0, 13.6], bold_first=True))

doc.add_paragraph()
paragraph = doc.add_paragraph()
run = paragraph.add_run("Hasil per Skenario")
run.bold = True
run.font.size = Pt(12)
run.font.color.rgb = GREEN

grid = table(
    doc,
    [("No", "Skenario dan yang diverifikasi", "Hasil")],
    [1.2, 14.6, 1.8],
    bold_first=True,
)
for index, (lead, body) in enumerate(SCENARIOS, 1):
    cells = grid.add_row().cells
    for cell, width in zip(cells, (1.2, 14.6, 1.8)):
        cell.width = Cm(width)
    cells[0].paragraphs[0].add_run(str(index)).font.size = Pt(9)
    cells[2].paragraphs[0].add_run("Lulus").font.size = Pt(9)
    cells[2].paragraphs[0].runs[0].bold = True
    cells[2].paragraphs[0].runs[0].font.color.rgb = OK
    paragraph = cells[1].paragraphs[0]
    paragraph.paragraph_format.space_after = Pt(2)
    bold_run = paragraph.add_run(lead)
    bold_run.bold = True
    bold_run.font.size = Pt(9)
    paragraph.add_run(f" {body}").font.size = Pt(9)
keep_together(grid)

paragraph = doc.add_paragraph()
paragraph.add_run().add_break(WD_BREAK.PAGE)
run = paragraph.add_run("Cakupan dan Batasan")
run.bold = True
run.font.size = Pt(12)
run.font.color.rgb = GREEN

doc.add_paragraph(
    "Lapisan yang bergantung pada perangkat keras atau layanan eksternal diganti tiruan (fake) "
    "melalui override Riverpod, sehingga alur antarmuka diuji deterministik tanpa kamera, galeri, "
    "model TFLite, Groq, maupun Firebase:"
)
keep_together(table(doc, [("Provider", "Pengganti saat uji")] + PROVIDERS, [5.2, 12.4], bold_first=True))

gap = doc.add_paragraph(
    "Yang diuji adalah navigasi dan perilaku layar, bukan akurasi model maupun koneksi Firebase/Groq. "
    "Dua jalur sengaja tidak diuji: pembukaan kamera asli (memicu dialog izin native yang tidak "
    "deterministik) dan panggilan Groq sungguhan. Validator gambar pada kasus 11 tetap memakai codec "
    "asli perangkat, bukan tiruan."
)
gap.paragraph_format.space_before = Pt(8)

paragraph = doc.add_paragraph()
run = paragraph.add_run("Keluaran Konsol")
run.bold = True
run.font.size = Pt(12)
run.font.color.rgb = GREEN

for line in LOG.splitlines():
    paragraph = doc.add_paragraph()
    paragraph.paragraph_format.space_after = Pt(0)
    paragraph.paragraph_format.line_spacing = 1.0
    run = paragraph.add_run(line)
    run.font.name = "Consolas"
    run.font.size = Pt(8)

doc.save(r"C:\PBL-KEL4_TI3C_SEM5\qa\integration-test-report.docx")
print("saved")


