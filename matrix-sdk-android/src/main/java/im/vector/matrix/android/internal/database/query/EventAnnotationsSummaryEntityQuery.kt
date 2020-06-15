/*
 * Copyright 2019 New Vector Ltd
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package im.vector.matrix.android.internal.database.query

import im.vector.matrix.android.internal.database.model.EventAnnotationsSummaryEntity
import im.vector.matrix.android.internal.database.model.EventAnnotationsSummaryEntityFields
import im.vector.matrix.android.internal.database.model.TimelineEventEntity
import io.realm.Realm
import io.realm.RealmQuery
import io.realm.kotlin.where

internal fun EventAnnotationsSummaryEntity.Companion.where(realm: Realm, eventId: String): RealmQuery<EventAnnotationsSummaryEntity> {
    val query = realm.where<EventAnnotationsSummaryEntity>()
    query.equalTo(EventAnnotationsSummaryEntityFields.EVENT_ID, eventId)
    return query
}

internal fun EventAnnotationsSummaryEntity.Companion.whereInRoom(realm: Realm, roomId: String?): RealmQuery<EventAnnotationsSummaryEntity> {
    val query = realm.where<EventAnnotationsSummaryEntity>()
    if (roomId != null) {
        query.equalTo(EventAnnotationsSummaryEntityFields.ROOM_ID, roomId)
    }
    return query
}

internal fun EventAnnotationsSummaryEntity.Companion.create(realm: Realm, roomId: String, eventId: String): EventAnnotationsSummaryEntity {
    val obj = realm.createObject(EventAnnotationsSummaryEntity::class.java, eventId).apply {
        this.roomId = roomId
    }
    // Denormalization
    TimelineEventEntity.where(realm, roomId = roomId, eventId = eventId).findFirst()?.let {
        it.annotations = obj
    }
    return obj
}
internal fun EventAnnotationsSummaryEntity.Companion.getOrCreate(realm: Realm, roomId: String, eventId: String): EventAnnotationsSummaryEntity {
    return EventAnnotationsSummaryEntity.where(realm, eventId).findFirst()
            ?: EventAnnotationsSummaryEntity.create(realm, roomId, eventId).apply { this.roomId = roomId }
}