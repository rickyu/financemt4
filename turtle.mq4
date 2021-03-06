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

input double g_fund_amount = 10000; // 资金数量
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
int g_slippage = 3;
bool g_have_exit_buy = false;
bool g_have_exit_sell = false;

int g_order_slippage = 3;
COrderManager g_order_manager;
CBreakthroughManager g_breakthrough_manager;

datetime g_date = 0; // 当前日期


enum EnumBreakThourghDirection
{
   BREAK_THROUGH_UNKNOWN = 0,
   BREAK_THROUGH_UP,
   BREAK_THROUGH_DOWN
};
struct BreakThroughInfo
{
    int id;
    datetime date; // 突破日期
    double price; // 价格
    EnumBreakThourghDirection direction;  // 方向
    bool can_ignore;// 本次突破是否可以忽略
    BreakThroughInfo() {
        id = 0;
        date = 0;
        price = 0;
        direction = BREAK_THROUGH_UNKNOWN;
        can_ignore = true;
    }
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
   datetime cur_date = GetCurrentDate();
   //Print("PrepareData:g_date=",g_date, ",cur_date=",cur_date);

   if (cur_date != g_date) {
     
       // 日期发生变化，重新计算数据
       g_date = cur_date;
       g_max_price_in_10d = iHigh(g_symbol, PERIOD_D1, iHighest(g_symbol, PERIOD_D1, MODE_HIGH, 10, 1));
       g_min_price_in_10d = iLow(g_symbol, PERIOD_D1, iLowest(g_symbol, PERIOD_D1, MODE_LOW, 10, 1));
       g_max_price_in_20d = iHigh(g_symbol, PERIOD_D1, iHighest(g_symbol, PERIOD_D1, MODE_HIGH, 20, 1));
       g_min_price_in_20d = iLow(g_symbol, PERIOD_D1, iLowest(g_symbol, PERIOD_D1, MODE_LOW, 20, 1));
       g_max_price_in_55d = iHigh(g_symbol, PERIOD_D1, iHighest(g_symbol, PERIOD_D1, MODE_HIGH, 55, 1));
       g_min_price_in_55d = iLow(g_symbol, PERIOD_D1, iLowest(g_symbol, PERIOD_D1, MODE_LOW, 55, 1));  
       g_N = iN(g_symbol, PERIOD_D1, 20, 1);
       //PreparePositionUnit();
      // Print("date:", g_date, " symbol=", g_symbol, ",max_price_in_20d=", g_max_price_in_20d);
  
       g_have_exit_buy = false;
       g_have_exit_sell = false;  
   }
   g_cur_ask = MarketInfo(g_symbol, MODE_ASK);
   g_cur_bid = MarketInfo(g_symbol, MODE_BID);
   g_digits = MarketInfo(g_symbol, MODE_DIGITS);
   //Print("date:", g_date, " symbol=", g_symbol, ",ask=", g_cur_ask, ",bid=", g_cur_bid);

  
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
  // 找到上次突破日的所有订单，查看每个订单是否有亏损的平仓.
  // @return 1 : 亏损， 0 ，没有亏损, <0 出错
  int IsBreakThroughLost(BreakThroughInfo& breakthrough)
  {
      COrder orders[];
      int orders_count = g_order_manager.SelectOrdersByBreakthrough(g_symbol, breakthrough.id, orders);
      if (orders_count < 0) {
          return orders_count;
      }
      if (orders_count == 0) {
          // 突破没订单
          return 0;
      }
      for (int i=0; i<orders_count; ++i) {
          if (orders[i].IsLost()) {
              return 1;
          }
      }      
      return 0;
      
  }
  
bool HaveEnterSignalBySystem1()
{
    if (g_cur_breakthrough.date == GetCurrentDate() && g_cur_breakthrough.direction != BREAK_THROUGH_UNKNOWN ) {
      
            //Print("具备入市信号:break through=", g_cur_breakthrough.date);
            return !g_cur_breakthrough.can_ignore;
        
    }
    //Print("计算是否有突破:date=", GetCurrentDate());
      // 计算今天是否是发生了突破

          // 计算今天是否发生了突破
          if (g_cur_ask > g_max_price_in_55d) {
              g_last_breakthrough = g_cur_breakthrough;
               // 发生了55日向上突破
              g_cur_breakthrough.direction = BREAK_THROUGH_UP;
              g_cur_breakthrough.price = g_max_price_in_55d;
              g_cur_breakthrough.can_ignore = false;
              g_cur_breakthrough.date = GetCurrentDate();
              Print("发生了55日向上突破, 突破价格=", g_cur_breakthrough.price);
              
              
          
          }  else if (g_cur_ask > g_max_price_in_20d) {
              g_last_breakthrough = g_cur_breakthrough;
              g_cur_breakthrough.direction = BREAK_THROUGH_UP;
              g_cur_breakthrough.price = g_max_price_in_20d;
              g_cur_breakthrough.can_ignore = true;
               g_cur_breakthrough.date = GetCurrentDate();
              Print("发生了20日向上突破,突破价=",g_cur_breakthrough.price);
          } 
          if (g_cur_bid < g_min_price_in_55d) {
              g_last_breakthrough = g_cur_breakthrough;
              g_cur_breakthrough.direction = BREAK_THROUGH_DOWN;
              g_cur_breakthrough.price = g_min_price_in_55d;
               g_cur_breakthrough.can_ignore = false;
                g_cur_breakthrough.date = GetCurrentDate();
              Print("发生了55日向下突破,突破价格=",g_cur_breakthrough.price);
          } else if (g_cur_bid < g_min_price_in_20d) {
              g_last_breakthrough = g_cur_breakthrough;
              g_cur_breakthrough.direction = BREAK_THROUGH_DOWN;
              g_cur_breakthrough.price = g_min_price_in_20d;
               g_cur_breakthrough.can_ignore = true;
                g_cur_breakthrough.date = GetCurrentDate();
              Print("发生了20日向下突破,突破价格=",g_cur_breakthrough.price);
          }
      
      

      if (g_cur_breakthrough.date == GetCurrentDate() && g_cur_breakthrough.direction != BREAK_THROUGH_UNKNOWN && g_cur_breakthrough.can_ignore == true) {     
            // 存在上次突破日,看上一次突破是营利性还是亏损性突破(上一次突破怎么找?保存在文件中?)
            if (g_last_breakthrough.direction != BREAK_THROUGH_UNKNOWN && !IsBreakThroughLost(g_last_breakthrough)) {
               Print("上次突破不是亏损突破，忽略本次入市信号");
               return false;
            } else {
               g_cur_breakthrough.can_ignore = false;
               
               return true;
            }
        
      }
      return false;
}


  // 入市策略1
  void EnterMarketSystem1()
  {
      COrder orders[];
      int orders_count = g_order_manager.SelectOrders(g_symbol,orders);
      if (orders_count < 0) {
          Print("error:SelectOrder return ", orders_count);
          return;
      }
      
      if (orders_count == 0) {
          // 空仓，准备入场
           //尝试开仓:条件，发生了突破，且突破不能忽略；
          if (!HaveEnterSignalBySystem1()) {
              return;
          }
          //Print("准备进入, breakthrouth date=", g_cur_breakthrough.date);
          // 开仓，价格为突破价格
          bool isBuySignal = g_cur_breakthrough.direction == BREAK_THROUGH_UP ? true: false;
          double market_price = isBuySignal ? g_cur_ask : g_cur_bid;
          int op = isBuySignal ? OP_BUY : OP_SELL;
          double stoploss = isBuySignal ? market_price - 2*g_N : market_price + 2*g_N;
          if (MathAbs(market_price - g_cur_breakthrough.price) < 0.5*g_N) {
              int ticket = g_order_manager.OpenOrderSmart(g_symbol, op, g_position_unit_system1, market_price, g_slippage, stoploss);
              if (ticket > 0) {
                  // 下单成功
                  Print("开仓成功");
                  // 标记当前突破为不可忽略
                  
              }
              
              
          }
         
      } else {
         // 标记当前突破为1 （可以忽略）
          // 有仓位，判断是否能加仓
          //           //尝试加仓到最多4U: 今天突破了，买了1U,明天价格超过了0.5N，还继续买吗？
          // 条件：已经开仓，当前价格超过突破价格的0.5N, 1N, 1.5N, 如果已经开仓，则持续加仓到最多4U
         int total_unit = 0;
         int strong_related_unit = 0;
         int weak_related_unit = 0;
         // 可以加仓， 计算总头寸单位
         if (total_unit >= 12 || strong_related_unit >= 6 || weak_related_unit>=10) {
            //不能加
            return;
         }
         if (orders_count >= 4) {
             return;
         } 
         double total_lots = 0;
         for (int i=0; i<ArraySize(orders); ++i) {
             total_lots += orders[i].lots;
         }
         bool isBuySignal = orders[0].type == OP_BUY;
         double price = isBuySignal ? g_cur_ask : g_cur_bid;
         
         double position_limit = g_position_unit_system1 * 4;
         
         
         // 要计算加仓的价格, [突破价,突破价+0.5N, 突破价+N, 突破价+1.5N】
         // 如果有滑点，以上一份订单的实际成交价格为基础，有上限吗?允许最大滑点多少?]
         double lots  = position_limit - total_lots > g_position_unit_system1 ? g_position_unit_system1 : position_limit - total_lots;
         int slippage = 3;
         double stoploss = isBuySignal ? price - 2*g_N : price + 2*g_N;
       
         

          if (isBuySignal && 
          (price < orders[orders_count-1].open_price + 0.5*g_N || price > orders[orders_count-1].open_price+g_N)) {
              // 不满足加仓条件
              return;
          }
          if (!isBuySignal &&
          ( price > orders[orders_count-1].open_price - 0.5*g_N || price < orders[orders_count-1].open_price-g_N)) {
              // 不满足加仓条件
              return;
          }

         
         int ticket = g_order_manager.OpenOrder(g_symbol, isBuySignal?OP_BUY:OP_SELL, lots, price, slippage, stoploss);
         Print("下单:lots=", lots, ",price=", price, ", stoploss=", stoploss, ",ticket=", ticket);
         if (ticket > 0) {
            Print("加仓了");
            // 设置止损价格，需要调整以前订单的止损价格: 将之前的头寸止损价格提高0.5N
            for (int i=0; i<orders_count;++i) {
            
                double new_stoploss = isBuySignal?orders[i].open_price+0.5*g_N:orders[i].open_price-0.5*g_N;
                new_stoploss = NormalizeDouble(new_stoploss, MarketInfo(g_symbol, MODE_DIGITS));
                if (OrderModify(orders[i].ticket, orders[i].open_price, new_stoploss, 0, 0)) {
                    Print("update stoploss succeed:ticket=", orders[i].ticket, ", stoploss=", new_stoploss, ",N=",g_N);
                } else {
                    Print("update stoploss fail:ticket=", orders[i].ticket, ", stoploss=", new_stoploss, ",N=",g_N, ",error=", GetLastError());
                }
               
            }  
         }
         if (ticket < 0) {
             Print("Open order error:", GetLastError());
            
         }
          
      }

      
  
      
  }
 
  void ExitMarketForSystem1()
  {
     
     
     
     if (!g_have_exit_buy && g_cur_bid < g_min_price_in_10d) {
         g_have_exit_buy = true;
         Print("Exit: 跌破10日低点,bid= ", g_cur_bid, ",price_min_10d=", g_min_price_in_10d);
         // 跌破10日最低点，退出多头头寸
         for (int i=0; i<OrdersTotal(); ++i) {
           OrderSelect(i, SELECT_BY_POS);
           if (OrderSymbol() == g_symbol && (OrderType() == OP_BUY || OrderType() == OP_BUYLIMIT)) {
               if (OrderClose(OrderTicket(), OrderLots(), g_cur_bid, 3)) {
                   Print("takeprofit:succeed close order:ticket=", OrderTicket(), ",type=", OrderType(), ",open_price=", OrderOpenPrice(), ", close_price=", OrderClosePrice());
               } else {
                   Print("takeprofit:failed close order:ticket=", OrderTicket(), ",type=", OrderType(), ",open_price=", OrderOpenPrice());
               }
           } 
         }
     }
     
     if (!g_have_exit_sell && g_cur_ask > g_max_price_in_10d) {
         g_have_exit_sell  = true;
         Print("Exit: 突破10日高点,ask= ", g_cur_ask, ",price_max_10d=", g_max_price_in_10d);
         // 超过10日最高点，退出多头头寸
         for (int i=0; i<OrdersTotal(); ++i) {
           OrderSelect(i, SELECT_BY_POS);
           if (OrderType() == g_symbol && (OrderType() == OP_SELL || OrderType() == OP_SELLLIMIT)) {
               if (OrderClose(OrderTicket(), OrderLots(), g_cur_ask, 3)) {
                   Print("succeed close order:ticket=", OrderTicket(), ",type=", OrderType(), ",open_price=", OrderOpenPrice());
               } else {
                    Print("failed close order:ticket=", OrderTicket(), ",type=", OrderType(), ",open_price=", OrderOpenPrice());
               }
           } 
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
 
   // 1. 看是否到时间要更行N和汇率，更新N,同时计算所有仓位，看是否需要变化(部分卖出)
  // 2. 计算现有订单是否需要盈利卖出的
  // 3. 看今天是否有突破（入市信号)，如果有不能忽略的入市信号， 则进行如下操作
  //     3.1 如果今天没有交易，根据突破价尝试买入
  //     3.2 如果今天有交易, 尝试按照0.5N的方式加仓
  
  
    PrepareData(symbol);
    ExitMarketForSystem1();
    EnterMarketSystem1();
   
 }
 void ProcessSystem2(string symbol)
 {
   //处理已有的头寸进行止损并控制头寸规模

   ExitMarketForSystem2();
   

   
    
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
    ProcessSystem1(Symbol());


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
