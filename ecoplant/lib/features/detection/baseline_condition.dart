import 'detection.dart';

/// Teks cadangan yang ditulis manusia, dipakai hanya ketika layanan caption
/// tidak dapat dihubungi. Bukan keluaran model bahasa.
String baselineConditionInfo(LeafClass leafClass) {
  switch (leafClass) {
    case LeafClass.healthy:
      return 'Daun teridentifikasi dalam kondisi sehat. Pada citra yang dianalisis, model tidak mengenali karakteristik utama dari penyakit Sigatoka, Cordana, maupun Pestalotiopsis.';

    case LeafClass.sigatoka:
      return 'Sigatoka merupakan penyakit bercak daun pada tanaman pisang. Gejalanya dapat berkembang dari bercak atau garis kecil pada daun menjadi area berwarna cokelat hingga kehitaman yang dapat mengurangi bagian daun yang tetap hijau.';

    case LeafClass.cordana:
      return 'Cordana merupakan penyakit bercak daun pada tanaman pisang. Kondisi ini umumnya ditandai dengan munculnya bercak pada permukaan daun yang dapat berkembang dan menyebabkan kerusakan pada jaringan daun.';

    case LeafClass.pestalotiopsis:
      return 'Pestalotiopsis merupakan kondisi penyakit daun yang berkaitan dengan infeksi jamur. Gejalanya dapat berupa bercak hingga kerusakan jaringan pada daun yang dapat berkembang apabila kondisi lingkungan mendukung.';
  }
}

String baselineTreatment(LeafClass leafClass) {
  switch (leafClass) {
    case LeafClass.healthy:
      return 'Pertahankan kondisi tanaman dengan melakukan pemantauan secara berkala, menjaga kebersihan area tanam, serta memastikan kebutuhan air dan nutrisi tanaman tetap terpenuhi.';

    case LeafClass.sigatoka:
      return 'Pantau perkembangan bercak pada daun dan jaga kebersihan area tanaman. Daun yang menunjukkan gejala berat dapat dipisahkan atau ditangani dengan hati-hati untuk mengurangi sumber infeksi. Konsultasikan penanganan lebih lanjut dengan tenaga ahli pertanian.';

    case LeafClass.cordana:
      return 'Pantau daun yang menunjukkan gejala, jaga sanitasi area tanam, dan hindari kondisi kelembapan berlebih di sekitar tanaman. Untuk gejala yang terus berkembang, konsultasikan penanganannya dengan tenaga ahli pertanian.';

    case LeafClass.pestalotiopsis:
      return 'Lakukan pemantauan terhadap perkembangan bercak, jaga kebersihan tanaman dan lingkungan sekitar, serta hindari kelembapan berlebih pada daun. Apabila gejala semakin luas, konsultasikan dengan tenaga ahli pertanian.';
  }
}
