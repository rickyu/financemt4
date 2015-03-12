//+------------------------------------------------------------------+
//|                                                        timer.mq4 |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(1);
   Print("OnInit");
      
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
      
  }
 void RunOnce()
 {
     string symbols[] = {"USDJPYpro", "EURUSDpro"};
     for (int i = 0; i<ArraySize(symbols); ++i) {
         
         Print("[timer]", i, " symbol:", symbols[i], ",ask=", MarketInfo(symbols[i], MODE_ASK));
     }
 }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
     RunOnce();
   
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
    RunOnce();

   
  }
//+------------------------------------------------------------------+
