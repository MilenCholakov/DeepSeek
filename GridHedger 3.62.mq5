//+------------------------------------------------------------------+
//|                                              GridHedgerMulti.mq5 |
//|                                                      Version 3.62|
//|       ДИНАМИЧЕН РИСК МЕНИДЖМЪНТ И ВОЛАТИЛНОСТ АДАПТАЦИЯ          |
//|               Ключови подобрения: Разделени SL/TP, Оптимизирани  |
//|               параметри за US30, Подобрена логика на грида       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version   "3.62"
#property strict
#include <Trade\Trade.mqh>
// Константи за различни символи
const double US30_POINT_MULTIPLIER = 0.1;   // 1 точка = 0.1 за US30
const double XAUUSD_POINT_MULTIPLIER = 0.01; // 1 точка = 0.01 за злато
const double EURUSD_POINT_MULTIPLIER = 0.00001; // 1 точка = 0.00001 за валути

// Функция за получаване на множител
double GetPointMultiplier()
{
   if(StringFind(_Symbol, "US30") >= 0 || StringFind(_Symbol, "DOW") >= 0)
      return US30_POINT_MULTIPLIER;
   else if(StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0)
      return XAUUSD_POINT_MULTIPLIER;
   else
      return _Point; // По подразбиране
}

// Функция за преобразуване от точки в цена
double PointsToPrice(double points)
{
   double pointValue = GetPointMultiplier();
   return points * pointValue;
}
CTrade Trade;
//+------------------------------------------------------------------+
//| Входни параметри (обновени за версия 3.62)                       |
//+------------------------------------------------------------------+
input group "=== ИДЕНТИФИКАЦИЯ ==="
input ulong   InpMagicNumber    = 987654321;     // УНИКАЛЕН Magic Number
input string  InpTradeComment   = "GridHedger";  // Коментар за поръчки
input bool    InpTradeOnlySymbol = true;         // Само на текущия символ

input group "=== ОСНОВНИ НАСТРОЙКИ ==="
input double   InpLotSize        = 0.1;          // Основен размер на лот
input int      InpMinDistance    = 200;          // Мин. дистанция в точки (оптимизирано)
input double   InpStopLossPoints = 300;          // НОВ: SL в точки (за всяка позиция)
input double   InpTakeProfitPoints = 1500;       // НОВ: TP в точки (за целия цикъл)
input bool     InpUseMartingale  = false;        // Използване на Мартингайл
input double   InpMartingaleMult = 2.0;          // Множител на Мартингайл

input group "=== ДИНАМИЧЕН РИСК МЕНИДЖМЪНТ ==="
input bool    InpUseDynamicRisk    = false;      // Изключен по подразбиране
input double  InpRiskPerTrade      = 1.0;        // Риск на сделка (% от баланса)
input double  InpMaxRiskPerDay     = 5.0;        // Макс. дневен риск (% от баланса)
input double  InpMaxPositionRisk   = 3.0;        // Макс. риск на позиция (% от баланса)
input bool    InpUseKellyCriterion = false;      // Използване на Kelly Criterion
input double  InpKellyPercent      = 25.0;       // % от Kelly (ако се използва)
input bool    InpReduceAfterLoss   = true;       // Намаляване на лота след загуба
input int     InpConsecutiveLosses = 2;          // Брой последователни загуби за намаляване

input group "=== ВОЛАТИЛНОСТ АДАПТАЦИЯ ==="
input bool    InpUseVolatilityAdjust = false;    // Изключен по подразбиране
input double  InpVolatilityThreshold = 1.5;      // Праг за висока волатилност (x ATR)
input bool    InpReduceHighVol       = false;    // Намаляване на лота при висока волатилност
input double  InpHighVolReduction    = 50.0;     // % намаляване при висока волатилност

input group "=== TRAILING STOP НАСТРОЙКИ ==="
input bool     InpUseTrailingStop    = false;    // Изключен по подразбиране
input double   InpTrailingStart      = 50.0;     // Trailing start (точки)
input double   InpTrailingDistance   = 30.0;     // Разстояние на Trailing Stop (точки)
input bool     InpUseATRTrailing     = false;    // Използване на ATR-based trailing
input double   InpATRTrailingMult    = 2.0;      // ATR множител за trailing
input bool     InpMoveToBreakeven    = true;     // Преместване на стоп на беззагубно ниво
input double   InpBreakevenTrigger   = 20.0;     // Активация на беззагубно ниво след (точки)
input bool     InpTrailAllPositions  = false;    // Прилагане на trailing за всички позиции
input bool     InpTrailOnlyGrid      = false;    // Само за грид позиции

input group "=== ВРЕМЕВ ИНТЕРВАЛ ==="
input bool     InpUseTradingTime = false;        // Използване на времеви интервал
input int      InpStartHour      = 0;            // Начален час (0-23)
input int      InpStartMinute    = 0;            // Начална минута
input int      InpEndHour        = 23;           // Краен час (0-23)
input int      InpEndMinute      = 59;           // Крайна минута

input group "=== ИНДИКАТОРНИ ФИЛТРИ ==="
input bool     InpUseIndicators  = false;        // Използване на индикатори
input bool     InpUseStochastic  = false;        // Използване на Stochastic
input int      InpStochKPeriod   = 14;           // Stochastic K период
input int      InpStochDPeriod   = 3;            // Stochastic D период
input int      InpStochSlowing   = 3;            // Stochastic заместване
input int      InpStochOverbought = 80;          // Overbought праг
input int      InpStochOversold  = 20;           // Oversold праг

input bool     InpUseRSI         = false;        // Използване на RSI
input int      InpRSIPeriod      = 14;           // RSI период
input int      InpRSIOverbought  = 70;           // RSI overbought
input int      InpRSIOversold    = 30;           // RSI oversold

input bool     InpUseATR         = false;        // Използване на ATR
input int      InpATRPeriod      = 14;           // ATR период
input double   InpATRMultiplier  = 1.5;          // ATR множител за разстояние

input bool     InpUseMA          = false;        // Използване на MA
input int      InpMAPeriod       = 50;           // MA период
input ENUM_MA_METHOD InpMAMethod = MODE_SMA;     // MA метод

input group "=== ХЕДЖИРАЩ ГРИД ==="
input int      InpGridStep       = 30;          // Оптимизирано: 15 пипса за US30
input int      InpGridMaxLevels  = 5;            // Макс. нива на грида
input double   InpGridVolumeMult = 1.0;          // Начален множител на обема (без увеличение)
input int      InpGridActivation = 100;          // Оптимизирано: 10 пипса активация
input double   InpMaxCycleLoss   = 500;          // НОВ: Макс. загуба за цикъл (точки)
/*
; === ХЕДЖИРАЩ ГРИД === (оптимизирани за US30)
InpGridStep       = 50     ; 5 пипса (вместо 150) - по-често хеджиране
*/
input group "=== РИСК МЕНИДЖМЪНТ ==="
input double   InpMaxDailyLoss   = 5000.0;       // Макс. дневна загуба ($)
input double   InpMaxRiskPercent = 20.0;         // Макс. риск (% от баланса)
input bool     InpUseEquityProtect = false;      // Защита на еквити
input double   InpEquityStopPercent = 30.0;      // Спиране при загуба на еквити (%)

input group "=== ДЕБЪГ И КОНТРОЛ ==="
input bool     InpEnableDebug    = true;         // Включване на дебъг съобщения
input bool     InpShowDashboard  = true;         // Показване на дашборд
input color    InpPanelColor     = clrGray;      // Цвят на панела
input bool     InpForceTrading   = false;        // Принудително търгуване (игнорира някои проверки)
input int      InpMaxSpread      = 100;          // Максимален спред в точки
input bool     InpIgnoreSpread   = true;         // Игнорира проверка на спреда (ВАЖНО за индекси!)
input int      InpMinStopDistance = 10;          // Мин. дистанция за стоп ордери (точки)

//+------------------------------------------------------------------+
//| Глобални променливи (обновени)                                  |
//+------------------------------------------------------------------+
enum ENUM_TRADE_STATE
{
   TRADE_STATE_IDLE,           // Без активност
   TRADE_STATE_PENDING,        // Чакащи поръчки
   TRADE_STATE_ONE_OPEN,       // Една отворена позиция
   TRADE_STATE_BOTH_OPEN,      // Двете позиции отворени
   TRADE_STATE_GRID_ACTIVE     // Активен хеджиращ грид
};

ENUM_TRADE_STATE tradeState = TRADE_STATE_IDLE;
ENUM_ORDER_TYPE_FILLING orderFillType;
datetime lastTradeTime = 0;
double dailyProfit = 0;
double initialEquity = 0;
bool tradingEnabled = true;

int buyStopTicket = -1;
int sellStopTicket = -1;
double entryPriceBuy = 0;
double entryPriceSell = 0;

int gridLevels = 0;
double gridPrices[100];

// Структура за позиции
struct PositionInfo
{
   ulong   ticket;
   double  openPrice;
   double  volume;
   ENUM_POSITION_TYPE type;
   double  profit;
   int     gridLevel;
   double  stopLoss;
   double  takeProfit;
};

PositionInfo activePositions[100];
int activePositionsCount = 0;

// Структура за trailing stop информация
struct TrailingInfo
{
   ulong   ticket;
   double  bestPrice;
   double  currentStop;
   bool    activated;
   bool    breakevenReached;
   double  activationPrice;
   bool    isGridPosition;
};

TrailingInfo trailingData[100];
int trailingCount = 0;

// Структура за риск метрики
struct RiskMetrics
{
   double dailyRiskUsed;      // Използван дневен риск
   double maxDailyRisk;       // Максимален дневен риск
   int    consecutiveLosses;  // Последователни загуби
   double winRate;           // Процент печеливши сделки
   int    totalTrades;       // Общ брой сделки
   int    winningTrades;     // Печеливши сделки
   double maxDrawdown;       // Максимален drawdown
   double peakBalance;       // Пиков баланс
};

RiskMetrics riskMetrics;

// Статистика за performance
struct TradeStats
{
   ulong   ticket;
   double  profit;
   datetime openTime;
   datetime closeTime;
   double  lotSize;
   string  symbol;
};

TradeStats tradeHistory[1000];
int tradeHistoryCount = 0;

// Хендли на индикатори
int hStochastic = INVALID_HANDLE;
int hRSI = INVALID_HANDLE;
int hATR = INVALID_HANDLE;
int hMA = INVALID_HANDLE;

// Допълнителни променливи
double tickSize = 0.0;
int stopsLevel = 0;
double minStopDistance = 0.0;

//+------------------------------------------------------------------+
//| Помощни функции                                                  |
//+------------------------------------------------------------------+
void DebugPrint(string message)
{
   if(InpEnableDebug)
      Print(TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), " [GridHedger v3.62] ", message);
}

string FormatTime(int hour, int minute)
{
   string hourStr = IntegerToString(hour);
   string minuteStr = IntegerToString(minute);
   
   if(hour < 10) hourStr = "0" + hourStr;
   if(minute < 10) minuteStr = "0" + minuteStr;
   
   return hourStr + ":" + minuteStr;
}

double NormalizePrice(double price)
{
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0) tick = _Point;
   
   double normalized = MathRound(price / tick) * tick;
   normalized = NormalizeDouble(normalized, _Digits);
   
   return normalized;
}

bool IsPriceValid(double price, ENUM_ORDER_TYPE orderType)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(price <= 0)
   {
      DebugPrint("Невалидна цена: " + DoubleToString(price, _Digits));
      return false;
   }
   
   if(orderType == ORDER_TYPE_BUY_STOP && price <= ask)
   {
      DebugPrint("BuyStop цена твърде близо до Ask: " + DoubleToString(price, _Digits));
      return false;
   }
   else if(orderType == ORDER_TYPE_SELL_STOP && price >= bid)
   {
      DebugPrint("SellStop цена твърде близо до Bid: " + DoubleToString(price, _Digits));
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   minStopDistance = stopsLevel * _Point;
   
   long nFilling = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   orderFillType = ((nFilling & SYMBOL_FILLING_FOK) > 0) ? ORDER_FILLING_FOK : 
                   ((nFilling & SYMBOL_FILLING_IOC) > 0) ? ORDER_FILLING_IOC : ORDER_FILLING_RETURN;
                    
   DebugPrint("=== ИНИЦИАЛИЗАЦИЯ НА СЪВЕТНИКА ===");
   DebugPrint("Версия: 3.62 - Оптимизирана за US30 със разделени SL/TP");
   DebugPrint("Символ: " + _Symbol);
   DebugPrint("Stop Loss: " + DoubleToString(InpStopLossPoints) + " точки");
   DebugPrint("Take Profit: " + DoubleToString(InpTakeProfitPoints) + " точки");
   DebugPrint("Grid Step: " + DoubleToString(InpGridStep) + " точки");
   
   if(InpStopLossPoints >= InpTakeProfitPoints)
   {
      DebugPrint("ПРЕДУПРЕЖДЕНИЕ: Stop Loss е по-голям или равен на Take Profit!");
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DebugPrint("Съветникът е деинициализиран. Причина: " + IntegerToString(reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Проверка за нов ден за нулиране на дневната печалба
   static datetime lastDay = 0;
   datetime currentDay = TimeCurrent() / 86400 * 86400;
   if(lastDay != currentDay)
   {
      dailyProfit = 0;
      lastDay = currentDay;
      DebugPrint("Нов ден - дневната печалба е нулирана");
   }
   
   // Актуализация на активните позиции
   UpdateActivePositions();
   
   // Основна логика за търговия
   CheckTradingConditions();
   ManageGrid();
   CheckCloseConditions();
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Проверка на търговските условия                                 |
//+------------------------------------------------------------------+
void CheckTradingConditions()
{
   // Проверка дали е разрешено търгуване
   if(!tradingEnabled) return;
   
   // Проверка за времеви интервал
   if(InpUseTradingTime)
{
   datetime current = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(current, dt);
   
   int startMinutes = InpStartHour * 60 + InpStartMinute;
   int endMinutes = InpEndHour * 60 + InpEndMinute;
   int currentMinutes = dt.hour * 60 + dt.min;
   
   if(currentMinutes < startMinutes || currentMinutes > endMinutes)
      return;
}
   // Проверка на спреда
   if(!InpIgnoreSpread)
   {
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > InpMaxSpread)
      {
         DebugPrint("Спредът е твърде висок: " + IntegerToString(spread) + " точки");
         return;
      }
   }
   
   // Логика за създаване на нова двойка ордери
   // Променете проверката за IDLE състояние:
    if(tradeState == TRADE_STATE_IDLE && !CheckExistingPendingOrders())
    {
        CreatePendingOrders();
    }
}

//+------------------------------------------------------------------+
//| Създаване на чакащи ордери                                       |
//+------------------------------------------------------------------+
void CreatePendingOrders()
{
   // Ако вече има чакащи ордери, не създавай нови
   if(CheckExistingPendingOrders())
    {
        tradeState = TRADE_STATE_PENDING;
        return;
   }
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double pointValue = GetPointMultiplier();
   
   // Изчисляване на цените за ордерите
   double buyStopPrice = NormalizePrice(ask + InpMinDistance * pointValue);
   double sellStopPrice = NormalizePrice(bid - InpMinDistance * pointValue);
   
   // Изчисляване на стоп лос нивата
   double buyStopLoss = NormalizePrice(buyStopPrice - InpStopLossPoints * pointValue);
   double sellStopLoss = NormalizePrice(sellStopPrice + InpStopLossPoints * pointValue);
   
   // Проверка на валидността на цените
   if(!IsPriceValid(buyStopPrice, ORDER_TYPE_BUY_STOP) || 
      !IsPriceValid(sellStopPrice, ORDER_TYPE_SELL_STOP))
      return;
   
   // Задаване на лот
   double lotSize = CalculateLotSize();
   
   // Изпращане на BuyStop ордер
   MqlTradeRequest buyRequest = {};
   MqlTradeResult buyResult = {};
   
   buyRequest.action = TRADE_ACTION_PENDING;
   buyRequest.symbol = _Symbol;
   buyRequest.volume = lotSize;
   buyRequest.type = ORDER_TYPE_BUY_STOP;
   buyRequest.price = buyStopPrice;
   buyRequest.sl = buyStopLoss;
   buyRequest.tp = 0; // TP се управлява от грид логиката
   buyRequest.magic = InpMagicNumber;
   buyRequest.comment = InpTradeComment;
   buyRequest.type_filling = orderFillType;
   
   if(OrderSend(buyRequest, buyResult))
   {
      buyStopTicket = (int)buyResult.order;
      DebugPrint("BuyStop поставена. Лот: " + DoubleToString(lotSize, 2) + 
                ", Цена: " + DoubleToString(buyStopPrice, _Digits) + 
                ", SL точки: " + DoubleToString(InpStopLossPoints));
   }
   else
   {
      DebugPrint("Грешка при поставяне на BuyStop: " + IntegerToString(GetLastError()));
      return;
   }
   
   // Изпращане на SellStop ордер
   MqlTradeRequest sellRequest = {};
   MqlTradeResult sellResult = {};
   
   sellRequest.action = TRADE_ACTION_PENDING;
   sellRequest.symbol = _Symbol;
   sellRequest.volume = lotSize;
   sellRequest.type = ORDER_TYPE_SELL_STOP;
   sellRequest.price = sellStopPrice;
   sellRequest.sl = sellStopLoss;
   sellRequest.tp = 0; // TP се управлява от грид логиката
   sellRequest.magic = InpMagicNumber;
   sellRequest.comment = InpTradeComment;
   sellRequest.type_filling = orderFillType;
   
   if(OrderSend(sellRequest, sellResult))
   {
      sellStopTicket = (int)sellResult.order;
      DebugPrint("SellStop поставена. Лот: " + DoubleToString(lotSize, 2) + 
                ", Цена: " + DoubleToString(sellStopPrice, _Digits) + 
                ", SL точки: " + DoubleToString(InpStopLossPoints));
   }
   else
   {
      DebugPrint("Грешка при поставяне на SellStop: " + IntegerToString(GetLastError()));
      // Ако SellStop не успее, изтриваме и BuyStop
      //OrderDelete((ulong)buyStopTicket);
      if(buyStopTicket > 0) 
         Trade.OrderDelete(buyStopTicket);
      return;
   }
   
   tradeState = TRADE_STATE_PENDING;
   DebugPrint("УСПЕХ: Поставени BuyStop и SellStop поръчки!");
}

//+------------------------------------------------------------------+
//| Изчисляване на размера на лота                                   |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double lotSize = InpLotSize;
   
   // Динамичен риск мениджмънт
   if(InpUseDynamicRisk)
   {
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = accountBalance * (InpRiskPerTrade / 100.0);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double stopLossPrice = InpStopLossPoints * GetPointMultiplier();
      
      if(tickValue > 0 && stopLossPrice > 0)
      {
         lotSize = riskAmount / (stopLossPrice * tickValue);
      }
   }
   
   // Намаляване след загуби
   if(InpReduceAfterLoss && riskMetrics.consecutiveLosses >= InpConsecutiveLosses)
   {
      lotSize *= 0.5; // Намаляване с 50%
      DebugPrint("Лотът е намален с 50% след " + 
                IntegerToString(riskMetrics.consecutiveLosses) + " последователни загуби");
   }
   
   // Нормализация на лота
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathRound(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Обновяване на активните позиции                                 |
//+------------------------------------------------------------------+
void UpdateActivePositions()
{
   activePositionsCount = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            PositionInfo pos;
            pos.ticket = ticket;
            pos.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            pos.volume = PositionGetDouble(POSITION_VOLUME);
            pos.type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            pos.profit = PositionGetDouble(POSITION_PROFIT);
            pos.gridLevel = 0; // По подразбиране
            pos.stopLoss = PositionGetDouble(POSITION_SL);
            pos.takeProfit = PositionGetDouble(POSITION_TP);
            
            // Определяне на ниво на грида от коментара
            string comment = PositionGetString(POSITION_COMMENT);
            if(StringFind(comment, "Grid_L") >= 0)
            {
               int startPos = StringFind(comment, "Grid_L") + 6;
               string levelStr = StringSubstr(comment, startPos, 1);
               pos.gridLevel = (int)StringToInteger(levelStr);
            }
            
            if(activePositionsCount < 100)
            {
               activePositions[activePositionsCount] = pos;
               activePositionsCount++;
            }
         }
      }
   }
   
   // Обновяване на състоянието
   if(activePositionsCount == 0)
   {
      tradeState = TRADE_STATE_IDLE;
      gridLevels = 0;
   }
   else if(activePositionsCount == 1)
   {
      tradeState = TRADE_STATE_ONE_OPEN;
   }
   else
   {
      // Проверка дали имаме и двете посоки
      bool hasBuy = false, hasSell = false;
      for(int i = 0; i < activePositionsCount; i++)
      {
         if(activePositions[i].type == POSITION_TYPE_BUY) hasBuy = true;
         if(activePositions[i].type == POSITION_TYPE_SELL) hasSell = true;
      }
      
      if(hasBuy && hasSell)
      {
         tradeState = TRADE_STATE_BOTH_OPEN;
      }
      else if(tradeState == TRADE_STATE_ONE_OPEN && activePositionsCount > 1)
      {
         tradeState = TRADE_STATE_GRID_ACTIVE;
      }
   }
}

//+------------------------------------------------------------------+
//| Управление на грида                                              |
//+------------------------------------------------------------------+
void ManageGrid()
{
   if(tradeState != TRADE_STATE_ONE_OPEN && tradeState != TRADE_STATE_GRID_ACTIVE)
      return;
   
   // Намиране на първоначалната позиция
   PositionInfo initialPosition = {0, 0.0, 0.0, WRONG_VALUE, 0.0, 0, 0.0, 0.0};

   bool foundInitial = false;
   
   for(int i = 0; i < activePositionsCount; i++)
   {
      if(activePositions[i].gridLevel == 0)
      {
         initialPosition = activePositions[i];
         foundInitial = true;
         break;
      }
   }
   
   if(!foundInitial) return;
   
   // Проверка дали трябва да се активира грид
   // ИЗЧИСЛЯВАНЕ В ТОЧКИ (не в пари):
   double currentPrice = (initialPosition.type == POSITION_TYPE_BUY) ? 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double pointsDiff = MathAbs(currentPrice - initialPosition.openPrice) / GetPointMultiplier();
   
   // Активация при достигане на InpGridActivation точки
   if(pointsDiff >= InpGridActivation && tradeState != TRADE_STATE_GRID_ACTIVE)
   {
       tradeState = TRADE_STATE_GRID_ACTIVE;
       gridLevels = 1; // Имаме 1 ниво (първоначалната позиция)
       DebugPrint("АКТИВАЦИЯ НА ГРИД! Точки: " + DoubleToString(pointsDiff));
   }
   
   // === ДОБАВЕТЕ ТОВА === //
   // Логика за отваряне на нови грид нива (ако гридът вече е активен)
   if(tradeState == TRADE_STATE_GRID_ACTIVE)
   {
       double priceStep = InpGridStep * GetPointMultiplier(); // Стъпка в цена
       double nextGridPrice;
       
       if(initialPosition.type == POSITION_TYPE_BUY)
       {
           // За BUY позиция, отваряме SELL на по-ниски нива
           nextGridPrice = initialPosition.openPrice - gridLevels * priceStep;
           if(SymbolInfoDouble(_Symbol, SYMBOL_BID) <= nextGridPrice && 
              gridLevels < InpGridMaxLevels)
           {
               OpenGridPosition(POSITION_TYPE_SELL, nextGridPrice, gridLevels);
               gridLevels++; // Увеличете брояча
           }
       }
       else // POSITION_TYPE_SELL
       {
           // За SELL позиция, отваряме BUY на по-високи нива
           nextGridPrice = initialPosition.openPrice + gridLevels * priceStep;
           if(SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= nextGridPrice && 
              gridLevels < InpGridMaxLevels)
           {
               OpenGridPosition(POSITION_TYPE_BUY, nextGridPrice, gridLevels);
               gridLevels++; // Увеличете брояча
           }
       }
   }
// === КРАЙ НА ДОБАВЯНЕТО === //
}

//+------------------------------------------------------------------+
//| Отваряне на грид позиция                                         |
//+------------------------------------------------------------------+
void OpenGridPosition(ENUM_POSITION_TYPE type, double price, int level)
{
   double lotSize = CalculateLotSize() * MathPow(InpGridVolumeMult, level);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = price;
   request.sl = 0; // Грид позициите нямат SL
   request.tp = 0;
   request.magic = InpMagicNumber;
   request.comment = InpTradeComment + "_Grid_L" + IntegerToString(level);
   request.type_filling = orderFillType;
   
   if(OrderSend(request, result))
   {
      DebugPrint("Грид позиция отворена. Ниво: " + IntegerToString(level) + 
                ", Тип: " + EnumToString(type) + 
                ", Лот: " + DoubleToString(lotSize, 2) + 
                ", Цена: " + DoubleToString(price, _Digits));
   }
   else
   {
      DebugPrint("Грешка при отваряне на грид позиция: " + IntegerToString(GetLastError()));
   }
}

void CheckCloseConditions()
{
    if(activePositionsCount == 0) return;
    
    // Намерете ПЪРВОНАЧАЛНАТА позиция (gridLevel == 0)
    PositionInfo initialPos = {0};
    for(int i = 0; i < activePositionsCount; i++)
    {
        if(activePositions[i].gridLevel == 0)
        {
            initialPos = activePositions[i];
            break;
        }
    }
    if(initialPos.ticket == 0) return;
    
    // Изчислете в ТОЧКИ
    double currentPrice = (initialPos.type == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double pointsDiff = (currentPrice - initialPos.openPrice) / GetPointMultiplier();
    
    // Обърнете за SELL позиции
    if(initialPos.type == POSITION_TYPE_SELL) pointsDiff = -pointsDiff;
    
    // Проверка за TP
    if(pointsDiff >= InpTakeProfitPoints)
    {
        DebugPrint("ДОСТИГНАТ TP! Точки: " + DoubleToString(pointsDiff));
        CloseAllPositions();
        return;
    }
    
    // Проверка за Max Loss
    if(pointsDiff <= -InpMaxCycleLoss)
    {
        DebugPrint("ДОСТИГНАТА МАКС. ЗАГУБА! Точки: " + DoubleToString(pointsDiff));
        CloseAllPositions();
        return;
    }
}
//+------------------------------------------------------------------+
//| Затваряне на всички позиции                                      |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   DebugPrint("Затваряне на ВСИЧКИ ПОЗИЦИИ...");
   
   for(int i = activePositionsCount - 1; i >= 0; i--)
   {
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_DEAL;
      request.symbol = _Symbol;
      request.volume = activePositions[i].volume;
      request.type = (activePositions[i].type == POSITION_TYPE_BUY) ? 
                     ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price = (activePositions[i].type == POSITION_TYPE_BUY) ? 
                     SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                     SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      request.magic = InpMagicNumber;
      request.comment = "Close_All";
      request.type_filling = orderFillType;
      
      if(OrderSend(request, result))
      {
         DebugPrint("Позиция затворена: " + IntegerToString(activePositions[i].ticket));
      }
      else
      {
         DebugPrint("Грешка при затваряне на позиция: " + IntegerToString(GetLastError()));
      }
   }
   
   // Нулиране на състоянието
   tradeState = TRADE_STATE_IDLE;
   gridLevels = 0;
   activePositionsCount = 0;
   
   DebugPrint("ВСИЧКИ ПОЗИЦИИ ЗАТВОРЕНИ. Връщане в IDLE състояние.");
}

//+------------------------------------------------------------------+
//| Обновяване на дашборда                                           |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!InpShowDashboard) return;
   
   // Тук може да се добави код за изчертаване на панел с информация
   // За сега само ще отпечатаме информация в журнала
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate >= 60)
   {
      DebugPrint("Статус: " + EnumToString(tradeState) + 
                ", Активни позиции: " + IntegerToString(activePositionsCount) + 
                ", Нива на грида: " + IntegerToString(gridLevels));
      lastUpdate = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Функция за обработка на събития за търговия                      |
//+------------------------------------------------------------------+
void OnTrade()
{
   // Когато има търговско събитие, обновяваме активните позиции
   UpdateActivePositions();
}
//+------------------------------------------------------------------+

bool CheckExistingPendingOrders()
{
    // Проверка за съществуващи BuyStop/SellStop ордери
    for(int i = OrdersTotal()-1; i>=0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(OrderSelect(ticket))
        {
            if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
               OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
            {
                ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
                    return true;
            }
        }
    }
    return false;
}