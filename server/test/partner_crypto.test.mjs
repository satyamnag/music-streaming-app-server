import { encryptDocument, decryptDocument, validateDocumentUpload, sniffDocumentType, generateToken, safeEqual, maskEmail, maskGovernmentId, hashIp } from "../partner_crypto.mjs";

const secrets = { partner_kek: "0".repeat(63) + "1" };
const getSecrets = () => secrets;

let pass = 0, fail = 0;
function check(name, cond) { if (cond) { pass++; console.log("  PASS " + name); } else { fail++; console.log("  FAIL " + name); } }

// --- round-trip ---
const plain = Buffer.from("%PDF-1.7\nsecret KYC bytes \u20b9\n%%EOF");
const { ciphertext, enc } = encryptDocument(plain, getSecrets);
check("ciphertext differs from plaintext", !ciphertext.equals(plain));
check("ciphertext contains no plaintext marker", !ciphertext.toString("latin1").includes("secret KYC"));
const back = decryptDocument(ciphertext, enc, getSecrets);
check("decrypt round-trips", back.equals(plain));

// --- unique DEK/IV per call ---
const a = encryptDocument(plain, getSecrets);
const b = encryptDocument(plain, getSecrets);
check("IV differs per encryption", a.enc.iv !== b.enc.iv);
check("wrapped DEK differs per document", a.enc.dekWrapped !== b.enc.dekWrapped);
check("same plaintext yields different ciphertext", !a.ciphertext.equals(b.ciphertext));

// --- tamper detection (GCM auth) ---
const tampered = Buffer.from(ciphertext); tampered[0] ^= 0xff;
let threw = false;
try { decryptDocument(tampered, enc, getSecrets); } catch (e) { threw = true; }
check("tampered ciphertext is rejected", threw);

// --- wrong KEK rejected ---
let threw2 = false;
try { decryptDocument(ciphertext, enc, () => ({ partner_kek: "f".repeat(64) })); } catch (e) { threw2 = true; }
check("wrong KEK is rejected", threw2);

// --- fail closed with no KEK ---
let threw3 = false;
try { encryptDocument(plain, () => ({})); } catch (e) { threw3 = true; }
check("missing KEK throws (fail-closed, never plaintext)", threw3);

// --- malformed KEK ---
let threw4 = false;
try { encryptDocument(plain, () => ({ partner_kek: "short" })); } catch (e) { threw4 = true; }
check("malformed KEK throws", threw4);

// --- file sniffing ---
check("PDF sniffed", sniffDocumentType(Buffer.from("%PDF-1.4"))?.mime === "application/pdf");
check("PNG sniffed", sniffDocumentType(Buffer.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a,0,0]))?.mime === "image/png");
check("JPEG sniffed", sniffDocumentType(Buffer.from([0xff,0xd8,0xff,0xe0,0,0,0,0]))?.mime === "image/jpeg");
check("random bytes rejected", sniffDocumentType(Buffer.from("not a real file at all")) === null);

// --- upload validation ---
const pdf = Buffer.from("%PDF-1.7 hello");
check("valid pdf accepted", validateDocumentUpload({ buffer: pdf, declaredMime: "application/pdf", filename: "pan.pdf" }).ok);
check("spoofed type rejected", validateDocumentUpload({ buffer: pdf, declaredMime: "image/png", filename: "x.png" }).reason === "type_mismatch");
check("disallowed declared type rejected", validateDocumentUpload({ buffer: pdf, declaredMime: "application/zip", filename: "x.zip" }).ok === false);
check("NTFS ADS colon rejected", validateDocumentUpload({ buffer: pdf, declaredMime: "application/pdf", filename: "pan.pdf:.jpg" }).reason === "invalid_filename");
check("traversal rejected", validateDocumentUpload({ buffer: pdf, declaredMime: "application/pdf", filename: "../../etc/passwd" }).reason === "invalid_filename");
check("dotfile rejected", validateDocumentUpload({ buffer: pdf, declaredMime: "application/pdf", filename: ".htaccess" }).reason === "invalid_filename");
check("null byte rejected", validateDocumentUpload({ buffer: pdf, declaredMime: "application/pdf", filename: "pan\u0000.pdf" }).reason === "invalid_filename");
check("oversize rejected", validateDocumentUpload({ buffer: Buffer.concat([pdf, Buffer.alloc(6*1024*1024)]), declaredMime: "application/pdf", filename: "big.pdf" }).reason === "file_too_large");
check("empty rejected", validateDocumentUpload({ buffer: Buffer.alloc(0), declaredMime: "application/pdf", filename: "e.pdf" }).reason === "empty_file");

// --- tokens ---
const t1 = generateToken(), t2 = generateToken();
check("token is 256-bit base64url", t1.length === 43 && t1 !== t2);
check("safeEqual true", safeEqual("abc", "abc"));
check("safeEqual false", !safeEqual("abc", "abd"));
check("safeEqual length mismatch", !safeEqual("abc", "abcd"));

// --- masking ---
check("email masked", maskEmail("satyam@example.com") === "sa****@example.com");
check("pan masked", maskGovernmentId("ABCDE1234F") === "******234F");
check("short id masked fully", maskGovernmentId("AB") === "****");
check("ip hashed, stable, not raw", (() => { const h = hashIp("1.2.3.4", "s"); return h === hashIp("1.2.3.4","s") && h !== hashIp("1.2.3.5","s") && !h.includes("1.2.3.4"); })());

console.log("\n" + pass + " passed, " + fail + " failed");
process.exit(fail === 0 ? 0 : 1);
