#!/usr/bin/env python3
"""Mechanical Firestore -> backend replacements for season_service.dart."""
from pathlib import Path

path = Path("lib/services/season_service.py")
if not path.exists():
    path = Path("lib/services/season_service.dart")

text = path.read_text(encoding="utf-8")

replacements = [
    ("Season.fromFirestore(doc)", "_seasonFromMap(doc)"),
    ("Season.fromFirestore(seasonDoc)", "_seasonFromMap(seasonDoc.data() if hasattr(seasonDoc, 'data') else seasonDoc)"),
    ("await _firestore.collection('users').doc(uid).get()", "await _backend.getUser(uid)"),
    ("final doc = await _backend.getUser(uid)", "final userDoc = await _backend.getUser(uid)"),
    ("(doc.data()?['role']", "(userDoc['role']"),
    ("doc.data()?['role']", "userDoc['role']"),
    ("doc.data()?['displayName']", "userDoc['displayName']"),
    ("doc.data()?['name']", "userDoc['name']"),
    ("doc.exists", "userDoc.isNotEmpty"),
    ("if (!doc.exists)", "if (userDoc.isEmpty)"),
    ("if (doc.exists)", "if (userDoc.isNotEmpty)"),
    ("await _firestore.collection('seasons').doc(seasonId).get()", "await _backend.getSeason(seasonId)"),
    ("await _firestore.collection('seasons').doc(seasonId).delete()", "await _backend.deleteSeason(seasonId)"),
    ("await _firestore.collection('seasons').doc(seasonId).update(", "await _backend.patchSeason(seasonId, "),
    ("await seasonDoc.reference.update(", "await _backend.patchSeason(seasonId, "),
    ("await doc.reference.update(", "await _backend.patchSeason(seasonId, "),
    ("FieldValue.serverTimestamp()", "DateTime.now().toIso8601String()"),
    ("FieldValue.arrayUnion([", "/*arrayUnion*/["),
    ("FieldValue.arrayRemove([", "/*arrayRemove*/["),
    ("FieldValue.delete()", "null"),
    ("FieldValue.increment(", "/*increment*/("),
    ("Timestamp.fromDate(", "/*ts*/"),
    ("FirestoreSafe.stream(", "/*poll*/"),
    ("import 'package:cloud_firestore/cloud_firestore.dart';\n", ""),
]

for old, new in replacements:
    text = text.replace(old, new)

# createSeason block
text = text.replace(
    "final seasonId = _firestore.collection('seasons').doc().id;",
    "final draft = await _backend.createSeason({'title': title, 'status': 'active'});\n      var seasonId = (draft['id'] ?? '').toString();",
)
text = text.replace(
    "await _firestore.collection('seasons').doc(seasonId).set(payload);",
    "payload['id'] = seasonId;\n      final created = await _backend.createSeason(payload);\n      seasonId = (created['id'] ?? seasonId).toString();",
)

path.write_text(text, encoding="utf-8")
print("Wrote", path, "firestore refs:", text.count("_firestore"))
