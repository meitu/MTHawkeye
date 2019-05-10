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


#include <list>
#include <unordered_map>

#include <dlfcn.h> // 所以包含 value 的头文件进来
#define KeyType uintptr_t
#define ValueType Dl_info

using namespace std;

// map value 结构
typedef struct LFUMapValue {
    ValueType value;
    list<pair<int, list<KeyType>>>::iterator main_it;
    list<KeyType>::iterator sub_it;
} LFUMapValue;


class MTHawkeyeLFUCache
{
  public:
    MTHawkeyeLFUCache(int capacity);
    ~MTHawkeyeLFUCache();
    ValueType get(KeyType key);             // 获取缓存，hash查找的复杂度
    void put(KeyType key, ValueType value); // 加入缓存，相同的key会覆盖，hash插入的复杂度
    void remove_key(KeyType key);           // 删除一个key
    void clear();                           // 删除全部

  private:
    int max_cap;
    int cur_cap;
    // 储存 pair<count, subList<key> > 结构，count 访问次数，count 小到大，key 时间由新到旧
    list<pair<int, list<KeyType>>> m_list;
    unordered_map<KeyType, LFUMapValue> u_map; // 储存 <key, LFUMapValue> 结构
    unordered_map<KeyType, LFUMapValue>::iterator map_it;

    void right_move(LFUMapValue *value); // 把一个节点的key向右提高访问次数
};
