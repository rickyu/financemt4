//+------------------------------------------------------------------+
//|                                                 Breakthrough.mqh |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property strict
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+


enum EnumBreakThourghDirection
{
   BREAK_THROUGH_UNKNOWN = 0,
   BREAK_THROUGH_UP,
   BREAK_THROUGH_DOWN
};
enum EnumTradeStatus
{
    TRADE_STATUS_HOLD = 1,// 还在继续持有
    TRADE_STATUS_PROFIT,// 盈利
    TRADE_STATUS_LOSS, // 亏损
};
struct BreakThroughInfo
{
    datetime t; // 发生突破的时间
    double price; // 突破价格
    EnumBreakThourghDirection direction;  // 方向
    EnumTradeStatus trade_status; // 
    BreakThroughInfo() {
        date = 0;
        price = 0;
        direction = BREAK_THROUGH_UNKNOWN;
        trade_status = TRADE_STATUS_HOLD;
    }
    void Init(datetime _t, EnumBreakThourghDirection _d, double _p) {
        t = _t;
        direction = _d;
        price = _p;
        trade_status = TRADE_STATUS_HOLD;
    }
    bool IsValid() const {
        return BREAK_THROUGH_UP == direction || BREAK_THROUGH_DOWN == direction;
    }
    bool IsLoss() const {
        return TRADE_STATUS_LOSS == trade_status;
    }

};
class CBreakthroughManager
{
public:
    
    void Load();
    int AddBreakthrough(const BreakThroughInfo& b);
    void GetBreakthrough();
    // 获取Breakthrough
    int  GetCurrentBreakthrough(BreakThroughInfo& b);
    int GetLastBreakthrough(BreakThroughInfo& b);
    void Update();
    int peroid() const;
    int frame() const;
private:
    int period_;
    int frame_;
    
};
int CBreakthroughManager::AddBreakthrough(const BreakThroughInfo &b)
{
    
}
void CBreakthroughManager::Update()
{
}