//+------------------------------------------------------------------+
//|                                                       turtle.mq4 |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

input double g_fund_amount = 50000; // 资金数量
input double g_system1_percent = 0.5; // 系统1使用的资金占比

double g_fund_amount_system1 = 0; // 系统1使用的资金量
double g_fund_amount_system2 = 0;  // 系统2使用的资金量
string g_symbols[] = {"EURUSD"};


double g_max_price_in_55d = 0.0; // 55日最高价
double g_min_price_in_55d = 0.0; // 55日最低价
double g_max_price_in_20d = 0.0; // 20日最高价
double g_min_price_in_20d = 0.0;
double g_max_price_in_10d = 0.0;
double g_min_price_in_10d = 0.0;

double g_N = 0.0; // 波动幅度N
string g_symbol = "";
double g_dollars_per_point = 1.0; // 没一点数所代表的美元
double g_position_unit_system1 = 0.01; // 头寸单位=账户的1%/市场的绝对波动幅度=账户的1%/(N*每一点数所代表的美元)
double g_position_unit_system2 = 0.01; // 头寸单位=账户的1%/市场的绝对波动幅度
double g_cur_bid = 0.0; // 当前bid价格
double g_cur_ask = 0.0; // 当前ask价格
void Log(const string& msg, int level)
{
  Print(msg);
}

double getDollarsPerPoint(string symbol)
{
   if (symbol == "USDJPY") {
     return 1/119.00; // 1点等于1日元，换算成美元
   } else {
     return 1;
   }
}

double iTR(string symbol, int timeframe, int shift)
{
  double TR = 0.0;
  double H = iHigh(symbol, timeframe, shift);
  double L = iLow(symbol, timeframe, shift);
  double PDC = iClose(symbol, timeframe, shift+1);
  TR = MathMax(H-L, MathMax(H-PDC, PDC-L));
  return TR;
}
double iN(string symbol, int timeframe, int period, int shift)
{
  double TR[];
  ArrayResize(TR, period);
  double sum = 0.0;
  
  for (int i=0; i<period; ++i) {
    sum  += iTR(symbol, timeframe, shift+i);
    
  }
  sum /= period;
  return sum;
  


}
 void PrepareData()
 {
 
   g_symbol = Symbol();
   Print("symbol:", g_symbol);
   
   g_max_price_in_10d = iHighest(g_symbol, PERIOD_D1, MODE_HIGH, 10, 0);
   g_min_price_in_10d = iLowest(g_symbol, PERIOD_D1, MODE_LOW, 10, 0);
   g_max_price_in_20d = iHighest(g_symbol, PERIOD_D1, MODE_HIGH, 20, 0);
   g_min_price_in_20d = iLowest(g_symbol, PERIOD_D1, MODE_LOW, 20, 0);
   g_max_price_in_55d = iHighest(g_symbol, PERIOD_D1, MODE_HIGH, 55, 0);
   g_min_price_in_55d = iLowest(g_symbol, PERIOD_D1, MODE_LOW, 55, 0);  
   g_cur_ask = Ask;
   g_cur_bid = Bid;
   g_N = iATR(g_symbol, PERIOD_D1, 20, 1);
   g_dollars_per_point = getDollarsPerPoint(g_symbol);
   g_position_unit_system1 = g_fund_amount_system1 * 0.01 / g_N / g_dollars_per_point;
   g_position_unit_system2 = g_fund_amount_system2 * 0.01 / g_N / g_dollars_per_point;
   
   Print("g_cur_ask=", g_cur_ask);
   Print("g_cur_bid=", g_cur_bid);
   Print("g_N=", g_N);
   Print("calculated N=", iN(g_symbol, PERIOD_D1, 20, 1));

   
   
 }
 // 止损处理
  void StopLoss(string symbol)
  {
      
      int order_total = OrdersTotal();
      int buy_orders[4];
      int buy_order_count;
      int sell_orders[4];
      int sell_order_count;
      // 根据买入价格计算symbol的止损价格，见page236
      for (int i = 0; i < order_total; ++i) {
        if (OrderSelect(i, SELECT_BY_POS) == false) {
          continue;
        }
        if (OrderSymbol() != symbol) {
          continue;
        }
        
        int type = OrderType();
        switch (type) {
          case OP_BUY: {
            buy_orders[buy_order_count] = OrderTicket();
            ++buy_order_count;
            

          } 
           break;
          case OP_SELL: {
          sell_orders[sell_order_count] = OrderTicket();
          ++sell_order_count;
             
          }
            break;
        }
      
      }
      for (int i=buy_order_count; i>=0; --i) {
        OrderSelect(buy_orders[i], SELECT_BY_TICKET);
        if (g_cur_bid < OrderOpenPrice() - 2 * g_N + (buy_order_count - i) * 0.5 * g_N) {
           OrderClose(buy_orders[i], OrderLots(), g_cur_bid, 3);
        } 
      }
      for (int i=sell_order_count; i>=0; --i) {
        OrderSelect(sell_orders[i], SELECT_BY_TICKET);
        if (g_cur_ask > OrderOpenPrice() + 2 * g_N - (sell_order_count - i) * 0.5 * g_N) {
          OrderClose(sell_orders[i], OrderLots(), g_cur_ask, 3);
        }
      }
       
  }
  // 双重损失止损策略
  void StopLoss_Whipsaw(string symbol)
  {
    int total = OrdersTotal();
    for (int i=0; i<total; ++i) {
      OrderSelect(i, SELECT_BY_POS);
      switch(OrderType()) {
        case OP_BUY:
          if (g_cur_bid < OrderOpenPrice() - 0.5*g_N) {
            OrderClose(OrderTicket(), OrderLots(), g_cur_bid, 3);
          }
          break;
        case OP_SELL:
          if (g_cur_ask > OrderOpenPrice() + 0.5 * g_N) {
            OrderClose(OrderTicket(), OrderLots(), g_cur_ask, 3);
          }
          break;
      }
    }
  }
  
  int Buy(string symbol, double volume, double price, string comment)
  {
     int ticket = OrderSend(symbol, OP_BUY, volume, price, 3, 0, 0, comment);
     if (ticket < 0) {
       Print("buy fail, error=", GetLastError());
     } else {
       
     }
     return ticket;
     
  }
  int Sell(string symbol, double volume, double price, string comment)
  {
       int ticket = OrderSend(symbol, OP_SELL, volume, price, 3, 0, 0, comment);
     if (ticket < 0) {
       Print("buy fail, error=", GetLastError());
     } else {
       
     }
     return ticket;
  }
  // 入市策略1
  void EnterMarketSystem1()
  {
     int long_position_count = 0; // 多头头寸单位
    int short_position_count = 0; // 空头头寸单位
    int long_position_count_for_symbol = 0; // 当前拥有的多头头寸单位
    int short_position_count_for_symbol = 0;
    double buy_price = g_max_price_in_20d;
    double sell_price = g_min_price_in_20d;
    
    
       int order_total = OrdersTotal();
       for (int i = 0; i < order_total; i++) {
         switch(OrderType()) {
           case OP_BUY:
             if (OrderSymbol() == g_symbol) {
               ++long_position_count_for_symbol;
               if (OrderOpenPrice() > buy_price) {
                 buy_price = OrderOpenPrice() + 0.5 * g_N;
               }
             }
             ++long_position_count;
             break;
           case OP_SELL:
             if (OrderSymbol() == g_symbol) {
               ++short_position_count_for_symbol;
               if (OrderOpenPrice() < sell_price) {
                 sell_price = OrderOpenPrice() - 0.5 * g_N;
               }
             }
             ++short_position_count;
             break;
         }
       }
    if (g_cur_ask >= buy_price) {
       // 进入多头, Buy
       // 任何一个方向的头寸单位不能超过12个
       if (long_position_count >= 12) {
         Print("头寸单位超过了12个");
         return;
       }
       if (long_position_count_for_symbol >= 4) {
         Print(g_symbol, "的多头头寸单位超过了4");
         return;
       }
       // TODO: 计算关联市场的头寸单位
       int ticket = Buy(g_symbol, g_position_unit_system1, g_cur_ask, "");
    }
    if (g_cur_bid <= sell_price) {
       // 进入空头
       if (short_position_count >= 12) {
         Print("头寸单位超过了12个");
         return;
       }
       if (short_position_count_for_symbol >= 4) {
         Print(g_symbol, "的空头头寸单位超过了4");
         return;
       }
       // TODO: 计算关联市场的头寸单位
       int ticket = Sell(g_symbol,  g_position_unit_system1 ,g_cur_bid, "");     
    }  
  }
  // 入市处理
  void EnterMarketSystem2() {
    int long_position_count = 0; // 多头头寸单位
    int short_position_count = 0; // 空头头寸单位
    int long_position_count_for_symbol = 0;
    int short_position_count_for_symbol = 0;
    double buy_price = g_max_price_in_55d;
    double sell_price = g_min_price_in_55d;
    
    
       int order_total = OrdersTotal();
       for (int i = 0; i < order_total; i++) {
         switch(OrderType()) {
           case OP_BUY:
             if (OrderSymbol() == g_symbol) {
               ++long_position_count_for_symbol;
               if (OrderOpenPrice() > buy_price) {
                 buy_price = OrderOpenPrice() + 0.5 * g_N;
               }
             }
             ++long_position_count;
             break;
           case OP_SELL:
             if (OrderSymbol() == g_symbol) {
               ++short_position_count_for_symbol;
               if (OrderOpenPrice() < sell_price) {
                 sell_price = OrderOpenPrice() - 0.5 * g_N;
               }
             }
             ++short_position_count;
             break;
         }
       }
    if (g_cur_ask >= buy_price) {
       // 进入多头, Buy
       // 任何一个方向的头寸单位不能超过12个
       if (long_position_count >= 12) {
         Print("头寸单位超过了12个");
         return;
       }
       if (long_position_count_for_symbol >= 4) {
         Print(g_symbol, "的多头头寸单位超过了4");
         return;
       }
       // TODO: 计算关联市场的头寸单位
       int ticket = Buy(g_symbol, g_position_unit_system2, g_cur_ask, "");
    }
    if (g_cur_bid <= sell_price) {
       // 进入空头
       if (short_position_count >= 12) {
         Print("头寸单位超过了12个");
         return;
       }
       if (short_position_count_for_symbol >= 4) {
         Print(g_symbol, "的空头头寸单位超过了4");
         return;
       }
       // TODO: 计算关联市场的头寸单位
       int ticket = Sell(g_symbol,  g_position_unit_system2 ,g_cur_bid, "");     
    }  
  }
  void ExitMarketForSystem1()
  {
     for (int i=0; i<OrdersTotal(); ++i) {
       OrderSelect(i, SELECT_BY_POS);
       if (OrderSymbol() != g_symbol) continue;
       if (OrderType() == OP_BUY && g_cur_bid < g_min_price_in_10d) {
         OrderClose(OrderTicket(), OrderLots(), g_cur_bid, 3);
         
       } else if (OrderType() == OP_SELL && g_cur_ask > g_max_price_in_10d) {
         OrderClose(OrderTicket(), OrderLots(), g_cur_ask, 3);
       }
       
     }
  }
    void ExitMarketForSystem2()
  {
     for (int i=0; i<OrdersTotal(); ++i) {
       OrderSelect(i, SELECT_BY_POS);
       if (OrderSymbol() != g_symbol) continue;
       if (OrderType() == OP_BUY && g_cur_bid < g_min_price_in_20d) {
         OrderClose(OrderTicket(), OrderLots(), g_cur_bid, 3);
         
       } else if (OrderType() == OP_SELL && g_cur_ask > g_max_price_in_20d) {
         OrderClose(OrderTicket(), OrderLots(), g_cur_ask, 3);
       }
       
     }
  }
  double calcDollarsPerPoint(string symbol) {
    return 0.0;
  }
 
 // 计算头寸单位
 double CalcPosition(double fund)
 {
     double ret = fund * 0.01 / g_N / calcDollarsPerPoint(Symbol());
     return ret;
     
 }
 

 void ProcessSystem1(string symbol)
 {
   StopLoss(symbol);
   ExitMarketForSystem1();
   // 处理头寸规模
   // 进入
   EnterMarketSystem1();
   
 }
 void ProcessSystem2(string symbol)
 {
   //处理已有的头寸进行止损并控制头寸规模
   StopLoss(symbol);
   ExitMarketForSystem2();
   
   EnterMarketSystem2();
   
    
   // 计算是不是要买入


 } 
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
    Print("fund amount= ", g_fund_amount);
    g_fund_amount_system1 = g_fund_amount * g_system1_percent;
    g_fund_amount_system2 = g_fund_amount - g_fund_amount_system1;
    
    Print("atr=", iATR(Symbol(), PERIOD_D1, 20, 5));
    Print("N=", iN(Symbol(), PERIOD_D1, 20, 5));
    Print("Point=", Point);
    Print("Lots size=", MarketInfo(Symbol(), MODE_LOTSIZE));
    Print("minumum allowed lot=", MarketInfo(Symbol(), MODE_MINLOT));
    
    PrepareData();
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
//---
    
     //ProcessSystem1(Symbol());
     //ProcessSystem2(Symbol());
   
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
