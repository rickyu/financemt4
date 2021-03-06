//+------------------------------------------------------------------+
//|                                                     Strategy.mqh |
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
#include <Object.mqh>
class CStrategy : public CObject
{
public:

};

class CPositionManager
{
public:
   void Update(bool force = false);
};
class CSystem1Strategy
{
public:
    void Init();
    void RunOnce();
    void Deinit();
private:
    CPositionManager* position_manager_;
    
};

void CSystem1Strategy::RunOnce(void)
{
  // 1. 看是否到时间要更行N，更新N,同时计算所有仓位，看是否需要变化(部分卖出)
  // 2. 计算现有订单是否需要盈利卖出的
  // 3. 看今天是否有突破（入市信号)，如果有不能忽略的入市信号， 则进行如下操作
  //     3.1 如果今天没有交易，根据突破价尝试买入
  //     3.2 如果今天有交易, 尝试按照0.5N的方式加仓
  position_manager_->Update();
  
  
}
