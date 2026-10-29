// UAS ADVANCED DATABASE SYSTEMS: 06_mongodb.js (TASK 5 - CPMK4)

// LANGKAH 1: LOG AKTIVITAS (120.000 Event)

use sentramart;

// LANGKAH 2: RANCANGAN SKEMA DOKUMEN & TRANSFORMASI KATALOG PRODUK
// Ngegabungin products.csv + product_attributes.csv (Model Embedding EAV)
/*
CONTOH DOKUMEN KOLEKSI 'products' YANG DIHASILKAN:
{
  "_id": 1,
  "seller_id": 870,
  "category_id": 1,
  "product_name": "Kairo Tablet Silver Seri-155",
  "price": 3294400,
  "stock": 285,
  "is_flash_sale": "false",
  "specs": {
    "brand": "Kairo",
    "ram_gb": 8,
    "storage_gb": 64,
    "network": "5G",
    "warranty_months": 12,
    "color": "Silver"
  }
}
*/

// LANGKAH 3: MEMBUAT INDEKS PERFORMA & TTL INDEX

// A. Compound Index untuk Pencarian Cepat Multiatribut (Setara Q3)
db.products.createIndex(
  { "category_id": 1, "specs.ram_gb": 1, "specs.network": 1, "price": 1, "stock": 1 },
  { name: "idx_products_spec_search" }
);

// B. Compound Index untuk Event Log Analitik
db.activity_logs.createIndex(
  { "event_type": 1, "ts": -1 },
  { name: "idx_logs_event_time" }
);

// C. Sparse Index untuk Error Code Voucher
db.activity_logs.createIndex(
  { "payload.error_code": 1 },
  { name: "idx_logs_voucher_error", sparse: true }
);

// D. TTL (Time-To-Live) Index: Otomatis Menghapus Log setelah 90 Hari (7.776.000 detik)
// Catatan: Jika field ts bertipe string ISO, konversi ke Date untuk aktivasi TTL background worker
db.activity_logs.createIndex(
  { "created_date": 1 },
  { expireAfterSeconds: 7776000, name: "idx_logs_ttl_90days", sparse: true }
);

// LANGKAH 4: EKSEKUSI 3 QUERY BISNIS & EXPLAIN ANALYZE

// QUERY 1: Filter Produk Spesifikasi (Setara Q3 EAV di PostgreSQL yang Lambat)
// Kasus: Kategori HP/Tablet (category_id: 1), RAM 8GB, Jaringan 5G, Harga 2jt-5jt, Stok > 0
db.products.find({
  category_id: 1,
  "specs.ram_gb": 8,
  "specs.network": "5G",
  price: { $gte: 2000000, $lte: 5000000 },
  stock: { $gt: 0 }
})
.sort({ price: 1 })
.limit(50)
.explain("executionStats");

// QUERY 2: Funnel Konversi Pengguna Harbolnas 12.12 (Agregasi Clickstream)
// Mengukur: View -> Add to Cart -> Apply Voucher -> Checkout Start -> Purchase
db.activity_logs.aggregate([
  {
    $match: {
      ts: {
        $gte: "2025-12-12T00:00:00",
        $lt: "2025-12-13T00:00:00"
      }
    }
  },
  {
    $group: {
      _id: "$event_type",
      total_interaksi: { $sum: 1 },
      total_user_unik: { $addToSet: "$customer_id" }
    }
  },
  {
    $project: {
      tahap_funnel: "$_id",
      total_interaksi: 1,
      jumlah_pengguna_aktif: { $size: "$total_user_unik" },
      _id: 0
    }
  },
  { $sort: { total_interaksi: -1 } }
]);

// QUERY 3: Top Kode Error Voucher Promo Selama Flash Sale 12.12
// Mengidentifikasi kendala pelanggan saat penukaran diskon
db.activity_logs.aggregate([
  {
    $match: {
      event_type: "apply_voucher",
      "payload.error_code": { $exists: true, $ne: null },
      ts: {
        $gte: "2025-12-12T00:00:00",
        $lt: "2025-12-13T00:00:00"
      }
    }
  },
  {
    $group: {
      _id: "$payload.error_code",
      frekuensi_error: { $sum: 1 }
    }
  },
  { $sort: { frekuensi_error: -1 } },
  { $limit: 5 }
]);
