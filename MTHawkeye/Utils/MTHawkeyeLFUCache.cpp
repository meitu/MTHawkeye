//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/1/29
// Created by: 曹堃
//


#import "MTHawkeyeLFUCache.hpp"

MTHawkeyeLFUCache::MTHawkeyeLFUCache(int capacity) {
    cur_cap = 0;
    max_cap = capacity;
    m_list.emplace_front(pair<int, list<KeyType>>(1, list<KeyType>())); // 插入 count == 1 的节点
}

MTHawkeyeLFUCache::~MTHawkeyeLFUCache() {
    m_list.clear();
    u_map.clear();
}

void MTHawkeyeLFUCache::right_move(LFUMapValue *value) {
    auto pre = value->main_it;
    auto pre_sub_it = value->sub_it;
    auto next = pre;
    next++;

    if (next != m_list.end()) {
        if (pre->first + 1 != next->first) { // 访问次数+1，判断是否相等
            if (pre->second.size() == 1) {
                pre->first++; // 这个 count 的 list 只有1个key，原地+1，不创建新节点
            } else {
                // next 前插入一个节点
                auto it = m_list.emplace(next, pair<int, list<KeyType>>(pre->first + 1, list<KeyType>()));
                it->second.splice(it->second.begin(), pre->second, pre_sub_it);
                value->main_it = it;
                value->sub_it = it->second.begin();
            }
        } else {
            // 追加在 next 的 sub_list 头部
            next->second.splice(next->second.begin(), pre->second, pre_sub_it);
            value->main_it = next;
            value->sub_it = next->second.begin();

            // 如果 pre.size == 0 则释放
            if (pre->second.size() == 0) {
                m_list.erase(pre);
            }
        }
    } else {
        if (pre->second.size() == 1) {
            pre->first++; // 原地+1
        } else {
            // 新建一个节点插入
            list<KeyType> tmp_list;
            tmp_list.splice(tmp_list.begin(), pre->second, pre_sub_it);
            // tmp_list 的迭代器不能用，加入 m_list 的时候会对，tmp_list进行拷贝构造，生成新的list插入，tmp_list被释放
            m_list.emplace_back(pair<int, list<KeyType>>(pre->first + 1, tmp_list));
            value->main_it = m_list.end();
            (value->main_it)--;
            value->sub_it = value->main_it->second.begin();
        }
    }
}

ValueType MTHawkeyeLFUCache::get(KeyType key) {
    map_it = u_map.find(key);
    if (map_it == u_map.end()) {
        return (ValueType){NULL, NULL, NULL, NULL};
    }

    LFUMapValue *value = &(map_it->second);
    right_move(value);

    return value->value;
}

void MTHawkeyeLFUCache::put(KeyType key, ValueType value) {
    if (max_cap == 0) {
        return;
    }
    map_it = u_map.find(key);
    if (map_it == u_map.end()) {
        // 找不到，插入
        list<KeyType> *firstList = &(m_list.front().second);
        if (cur_cap == max_cap) {
            // 淘汰一个
            if (firstList->size() > 0) {
                // u_map 中删除，list 中删除
                u_map.erase(firstList->back());
                firstList->pop_back();
                cur_cap--;
            }
        }
        cur_cap++;
        if (m_list.front().first != 1) {
            m_list.emplace_front(pair<int, list<KeyType>>(1, list<KeyType>()));
            firstList = &(m_list.front().second);
        }
        firstList->emplace_front(key);
        LFUMapValue map_value;
        map_value.value = value;
        map_value.main_it = m_list.begin();
        map_value.sub_it = firstList->begin();
        u_map[key] = map_value;
    } else {
        // 找得到，更新，提高一个访问次数
        map_it->second.value = value;
        right_move(&(map_it->second));
    }
}

void MTHawkeyeLFUCache::remove_key(KeyType key) {
    auto it = u_map.find(key);
    if (it != u_map.end()) {
        it->second.main_it->second.erase(it->second.sub_it); // 清除链表中的
        u_map.erase(it);
        cur_cap--;
    }
}

void MTHawkeyeLFUCache::clear() {
    m_list.clear();
    m_list.emplace_front(pair<int, list<KeyType>>(1, list<KeyType>())); // 插入 count == 1 的节点
    u_map.clear();
    cur_cap = 0;
}
