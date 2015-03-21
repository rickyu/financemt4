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
   Print("OnInit,currency=", AccountCurrency(), ", profit_currency=", SymbolInfoString(Symbol(), SYMBOL_CURRENCY_PROFIT));
   Print("min lot = ", MarketInfo(Symbol(), MODE_MINLOT), ", lot step=", MarketInfo(Symbol(), MODE_LOTSTEP));
      
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
 
 datetime g_t = 0;
 bool IsNewPeriod( int timeframe) 
 {
     if (g_t == 0) {
         g_t = TimeCurrent();
     }
     int c = iBars(Symbol(), timeframe);
     int shift = iBarShift(Symbol(), timeframe, g_t, true);
     // Print("symbol=", Symbol(), ", gt=", g_t, ",c=", c, ", shift=", shift);
     if (shift > 0) {
         Print("new period,gt=", g_t, ",new_time=",TimeCurrent());
        
         g_t = TimeCurrent();
         return true;
     }
     //Print("error=", GetLastError());
     return false;
 }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
     datetime t = MarketInfo(Symbol(), MODE_TIME);

    //IsNewPeriod(PERIOD_CURRENT);
   // Print("ask=", Ask, ",time=", iTime(Symbol(), PERIOD_CURRENT, 0));
   
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
