struct.utils for Lua 5.1.4

# generate description file
see `generate.lua`, make your '.h' files and `generate.lua` in the same directory. config it and run the script.

# usage for utils
first, take a table `StructDef` for C struct description, resolve it to dereference type in it.
```
local utils = require('struct.utils')
StructDef = {
--[[
typedef struct _tagCURRENCY_EXCHANGE{
	int						nUserID;
	TCY_CURRENCY_CONTAINER	nContainer;					
	TCY_CURRENCY			nCurrency;				
	int						nExchangeGameID;
    int                     llOperationIDLow;
    int                     llOperationIDHigh;
	int                     llBalanceLow;
    int                     llBalanceHigh;
	int						nOperateAmount;			//操作数量
	int						nCreateTime;
	DWORD					dwFlags;
	
	int						nReserved[8];
}CURRENCY_EXCHANGE, *LPCURRENCY_EXCHANGE;
--]]
CURRENCY_EXCHANGE = {
	{'nUserID', 'i'},
	{'nContainer', 'TCY_CURRENCY_CONTAINER'},
	{'nCurrency', 'TCY_CURRENCY'},
	{'nExchangeGameID', 'i'},
	{'llOperationIDLow', 'i'},
	{'llOperationIDHigh', 'i'},
	{'llBalanceLow', 'i'},
	{'llBalanceHigh', 'i'},
	{'nOperateAmount', 'i'},
	{'nCreateTime', 'i'},
	{'dwFlags', 'L'},
	{'nReserved', 'i', 8},
},
--[[
typedef struct _tagCURRENCY_EXCHANGE_EX{
	CURRENCY_EXCHANGE		currencyExchange;
	
	DWORD					dwNotifyFlags;
	int						nEnterRoomID;			//通知时带上的玩家所在房间roomid，和本次变化无关
	
	int						nReserved[16];
}CURRENCY_EXCHANGE_EX, *LPCURRENCY_EXCHANGE_EX;
--]]
CURRENCY_EXCHANGE_EX = {
	{'currencyExchange', 'CURRENCY_EXCHANGE'},
	{'dwNotifyFlags', 'L'},
	{'nEnterRoomID', 'i'},
	{'nReserved', 'i', 16},
},
} --StructDef

StructDef = utils.resolve(StructDef)
```
## struct pack for lua table
```
data = utils.pack(StructDef.CURRENCY_EXCHANGE_EX, {
	dwNotifyFlags = 2222,
	nEnterRoomID = 22458,
	currencyExchange = {
		nUserID = 77681,
		nContainer = 2,
		nCurrency = 2,
		nExchangeGameID = 384,
	}
})
```
## struct unpack to lua table
```
t = utils.unpack(data)
dump(t)
```