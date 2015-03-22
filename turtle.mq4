//+------------------------------------------------------------------+
//|                                                       turtle.mq4 |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#include "Order.mqh"
#include "Breakthrough.mqh"
#include "Strategy.mqh"

input double g_fund_amount = 10000; // 资金数量



CSystem1Strategy g_system1_strategy;


datetime GetCurrentDate()
{
    MqlDateTime dt;
    
    TimeCurrent(dt);
    dt.hour = 0;
    dt.min = 0;
    dt.sec = 0;
    return StructToTime(dt);
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  { 
//---
    
    System1Config config;
    config.fund = g_fund_amount;
    Print(config.ToString());
    g_system1_strategy.Init(config);
//---
   return(INIT_SUCCEEDED);
  }
  
 
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    Tick tick;
    //tick.symbol = Symbol();
    tick.ask = MarketInfo(Symbol(), MODE_ASK);
    tick.bid = MarketInfo(Symbol(), MODE_BID);
    tick.timestamp = MarketInfo(Symbol(), MODE_TIME);
    g_system1_strategy.ProcessTick(tick);   
  }
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+
