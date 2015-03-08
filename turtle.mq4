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
int g_digits = 0;
double g_dollars_per_point = 1.0; // 没一点数所代表的美元
double g_position_unit_system1 = 0.01; // 头寸单位=账户的1%/市场的绝对波动幅度=账户的1%/(N*每一点数所代表的美元)
double g_position_unit_system2 = 0.01; // 头寸单位=账户的1%/市场的绝对波动幅度
double g_cur_bid = 0.0; // 当前bid价格
double g_cur_ask = 0.0; // 当前ask价格

int g_order_slippage = 3;

datetime g_date = 0; // 当前日期


enum EnumBreakThourghDirection
{
   BREAK_THROUGH_UNKNOWN = 0,
   BREAK_THROUGH_UP,
   BREAK_THROUGH_DOWN
};
struct BreakThroughInfo
{
    datetime date; // 突破日期
    double price; // 价格
    EnumBreakThourghDirection direction;  // 方向
};
BreakThroughInfo g_last_breakthrough;
BreakThroughInfo g_cur_breakthrough;


void Log(const string& msg, int level)
{
  Print(msg);
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
/** 计算每点代表的美元数 */
double GetDollarsPerPoint(string symbol)
{
   double currency = MarketInfo(symbol, MODE_LOTSIZE) * MarketInfo(symbol, MODE_POINT);
   return currency/119.00;
   if (symbol == "USDJPYpro") {
     return 100000*0.001/119.570; // 一个合约100000日元，1点等于0.001涨跌，因此等于100日元，换算成美元
   } else {
     return 0;
   }
}
// 计算头寸规模单位，算法：头寸规模单位=账户的1%/市场的绝对波动幅度=账户的1%/(N * 每一点代表的美元数)
// 返回值：合约数，比如外汇的最小合约数是0.01，
double CalcPositionUnit(string symbol, double fund)
{
   double N_ = iATR(g_symbol, PERIOD_D1, 20, 1);
   double N = N_ /MarketInfo(symbol, MODE_POINT);  
   return NormalizeDouble(fund * 0.01 / (N * GetDollarsPerPoint(symbol)),2);// 0.01份合约，小数点后2位
}
void PreparePositionUnit() 
{
   g_dollars_per_point = GetDollarsPerPoint(g_symbol);
   g_position_unit_system1 = CalcPositionUnit(g_symbol, g_fund_amount_system1);
   g_position_unit_system2 = CalcPositionUnit(g_symbol, g_fund_amount_system2);
}

// 调整交易规模
datetime GetCurrentDate()
{
    MqlDateTime dt;
    
    TimeCurrent(dt);
    dt.hour = 0;
    dt.min = 0;
    dt.sec = 0;
    return StructToTime(dt);
}
 void PrepareData(string symbol)
 {
 
   g_symbol = symbol;

   if (GetCurrentDate() != g_date) {
       // 日期发生变化，重新计算数据
       g_date = GetCurrentDate();
       g_max_price_in_10d = iHigh(g_symbol, PERIOD_D1, iHighest(g_symbol, PERIOD_D1, MODE_HIGH, 10, 1));
       g_min_price_in_10d = iLow(g_symbol, PERIOD_D1, iLowest(g_symbol, PERIOD_D1, MODE_LOW, 10, 1));
       g_max_price_in_20d = iHigh(g_symbol, PERIOD_D1, iHighest(g_symbol, PERIOD_D1, MODE_HIGH, 20, 1));
       g_min_price_in_20d = iLow(g_symbol, PERIOD_D1, iLowest(g_symbol, PERIOD_D1, MODE_LOW, 20, 1));
       g_max_price_in_55d = iHigh(g_symbol, PERIOD_D1, iHighest(g_symbol, PERIOD_D1, MODE_HIGH, 55, 1));
       g_min_price_in_55d = iLow(g_symbol, PERIOD_D1, iLowest(g_symbol, PERIOD_D1, MODE_LOW, 55, 1));  
       g_N = iN(g_symbol, PERIOD_D1, 20, 1);
       PreparePositionUnit();
       if (g_cur_breakthrough.direction != BREAK_THROUGH_UNKNOWN) {
           g_last_breakthrough = g_cur_breakthrough;
       }
       g_cur_breakthrough.date = g_date;
       g_cur_breakthrough.price = 0.0;
       g_cur_breakthrough.direction = BREAK_THROUGH_UNKNOWN;

        Print("date:", g_date, " symbol=", g_symbol, ",max_price_in_20d=", g_max_price_in_20d);
  
       
   }
   g_cur_ask = MarketInfo(g_symbol, MODE_ASK);
   g_cur_bid = MarketInfo(g_symbol, MODE_BID);
   g_digits = MarketInfo(g_symbol, MODE_DIGITS);
   Print("date:", g_date, " symbol=", g_symbol, ",ask=", g_cur_ask, ",bid=", g_cur_bid);

  
 }
 // 止损处理
  void StopLoss(string symbol)
  {
      Print("enter StopLoss", __FUNCTION__);
      int order_total = OrdersTotal();
      Print("orders count = ", order_total);
      
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
      Print("N=", g_N);

      for (int i=buy_order_count-1; i>=0; --i) {
        OrderSelect(buy_orders[i], SELECT_BY_TICKET);
        double stop_loss_price = NormalizeDouble(OrderOpenPrice() - 2 * g_N + (buy_order_count - i) * 0.5 * g_N, g_digits);
        Print("买单 入市价=", OrderOpenPrice(), ", 止损价=", stop_loss_price);
        if (g_cur_bid < stop_loss_price) {
           OrderClose(buy_orders[i], OrderLots(), g_cur_bid, g_order_slippage);
        } 
      }
      for (int i=sell_order_count-1; i>=0; --i) {
        OrderSelect(sell_orders[i], SELECT_BY_TICKET);
        double stop_loss_price = NormalizeDouble(OrderOpenPrice() + 2 * g_N - (sell_order_count - i) * 0.5 * g_N, g_digits);
        Print("卖单 入市价=", OrderOpenPrice(), ", 止损价=", stop_loss_price);
        if (g_cur_ask > stop_loss_price) {
          OrderClose(sell_orders[i], OrderLots(), g_cur_ask, g_order_slippage);
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
  
  // 检查某次突破是不是亏损突破
  bool IsBreakThroughLost(BreakThroughInfo& breakthrough) {
      return true;
      
  }
  // 入市策略1
  void EnterMarketSystem1()
  {
      if (g_cur_breakthrough.direction == BREAK_THROUGH_UNKNOWN) {
          if (g_cur_ask > g_max_price_in_20d) {
              g_cur_breakthrough.direction = BREAK_THROUGH_UP;
              g_cur_breakthrough.price = g_max_price_in_20d;
          } 
          if (g_cur_bid < g_min_price_in_20d) {
              g_cur_breakthrough.direction = BREAK_THROUGH_DOWN;
              g_cur_breakthrough.price = g_min_price_in_20d;
          }
      }
      

      if (g_cur_breakthrough.direction != BREAK_THROUGH_UNKNOWN) {
         // 今天是突破日
         
        datetime break_time = MarketInfo(g_symbol, MODE_TIME);
        Print("产生了一次20日突破:价格=", g_cur_ask, ",20日最高价=", g_max_price_in_20d, " ,break_time=", break_time);
        
        if (g_last_breakthrough.direction != BREAK_THROUGH_UNKNOWN) {
            // 存在上次突破日,看上一次突破是营利性还是亏损性突破(上一次突破怎么找?保存在文件中?)
            if (!IsBreakThroughLost(g_last_breakthrough)) {
               Print("上次突破不是亏损突破，忽略本次入市信号");
               return;
            }
        }
        
      }
      return;
  
  
  
     int long_position_count = 0; // 多头头寸单位，假设一次下单一定会购买一个头寸单位
    int short_position_count = 0; // 空头头寸单位
    int long_position_count_for_symbol = 0; // 当前拥有的多头头寸单位
    int short_position_count_for_symbol = 0;
    double buy_price = g_max_price_in_20d;
    double sell_price = g_min_price_in_20d;
    
    
    //计算当前
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
     
    PrepareData(Symbol());
    PreparePositionUnit();
    Print("positin unit=", g_position_unit_system1);
    
    StopLoss(g_symbol);
    
   
    
    
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
   // Print("Tick");
//---
    PrepareData(Symbol());
    //EnterMarketSystem1();
    EnterMarketSystem1();
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
