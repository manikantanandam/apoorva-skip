//
//  FirestoreCoding.swift
//  ApoorvaServices
//

#if os(Android)
import SkipFirebaseFirestore

// skip-firebase exposes `FirestoreEncoder`/`FirestoreDecoder` on Android; Apple's SDK nests them in `Firestore`.
// This keeps call sites on `Firestore.Encoder()`/`Firestore.Decoder()` for both platforms.
extension Firestore {
    typealias Encoder = FirestoreEncoder
    typealias Decoder = FirestoreDecoder
}
#endif
