import { TtsSpeaker, keyToSpeech, resultToSpeech } from '../common/TtsSpeaker';

class CalculationResult {
  success: boolean;
  value: number;
  message: string;

  constructor(success: boolean, value: number, message: string) {
    this.success = success;
    this.value = value;
    this.message = message;
  }
}

@Entry
@Component
struct Index {
  @State inputText: string = '';
  @State resultText: string = '0';
  @State tipText: string = '点击数字或语音输入';
  @State isListening: boolean = false;

  private justCalculated: boolean = false;
  private readonly keys: string[][] = [
    ['C', '⌫', '÷', '×'],
    ['7', '8', '9', '−'],
    ['4', '5', '6', '+'],
    ['1', '2', '3', '='],
    ['语音', '0', '.', '确认']
  ];

  build() {
    Column({ space: 14 }) {
      this.TitleArea();
      this.DisplayArea();
      this.KeyBoardArea();
      this.VoiceArea();
    }
    .width('100%')
    .height('100%')
    .padding({ top: 28, right: 20, bottom: 20, left: 20 })
    .backgroundColor('#F5F7FA')
  }

  aboutToAppear(): void {
    // 页面出现时初始化 TTS 引擎；初始化是异步的，成功后再把提示区改为就绪状态
    TtsSpeaker.getInstance().init().then((ready: boolean) => {
      this.tipText = ready ? '语音播报已就绪，点击按键即可收听' : '语音播报初始化失败，当前设备可能不支持';
    });
  }

  aboutToDisappear(): void {
    // 页面销毁时释放 TTS 引擎，避免后台继续占用系统语音资源
    TtsSpeaker.getInstance().shutdown();
  }

  @Builder
  TitleArea() {
    Column({ space: 4 }) {
      Text('智能语音计算器')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2563EB')
      Text('语音输入 · 自动计算 · 结果播报')
        .fontSize(14)
        .fontColor('#6B7280')
    }
    .width('100%')
  }

  @Builder
  DisplayArea() {
    Column({ space: 8 }) {
      Text(this.inputText === '' ? '请输入表达式' : this.inputText)
        .fontSize(21)
        .fontColor(this.inputText === '' ? '#9CA3AF' : '#6B7280')
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.End)

      Text(this.resultText)
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(142)
    .justifyContent(FlexAlign.Center)
    .padding(16)
    .backgroundColor('#FFFFFF')
    .border({ width: 1, color: '#D8E2F0' })
    .borderRadius(14)
  }

  @Builder
  KeyBoardArea() {
    Column({ space: 10 }) {
      ForEach(this.keys, (row: string[], rowIndex: number) => {
        Row({ space: 10 }) {
          ForEach(row, (key: string, keyIndex: number) => {
            this.CalcButton(key);
          }, (key: string, keyIndex: number) => `${rowIndex}-${keyIndex}-${key}`)
        }
        .width('100%')
      }, (row: string[], rowIndex: number) => rowIndex.toString())
    }
    .width('100%')
  }

  @Builder
  CalcButton(key: string) {
    Button(key === '语音' ? '🎤' : key)
      .fontSize(key === '确认' ? 17 : 21)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.isOperator(key) ? '#2563EB' : '#111827')
      .width('22%')
      .height(52)
      .padding(0)
      .backgroundColor(this.isOperator(key) ? '#E8F1FF' : '#FFFFFF')
      .border({ width: 1, color: '#D8E2F0' })
      .borderRadius(12)
      .onClick(() => {
        this.handleKey(key);
      })
  }

  @Builder
  VoiceArea() {
    Row({ space: 8 }) {
      Text(this.isListening ? '●' : '○')
        .fontSize(13)
        .fontColor(this.isListening ? '#2563EB' : '#9CA3AF')
      Text(this.tipText)
        .fontSize(15)
        .fontColor(this.isListening ? '#2563EB' : '#6B7280')
        .maxLines(2)
    }
    .width('100%')
    .height(44)
    .justifyContent(FlexAlign.Center)
    .padding({ right: 12, left: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(10)
  }

  private handleKey(key: string): void {
    const speaker: TtsSpeaker = TtsSpeaker.getInstance();
    if (key === 'C') {
      this.clearAll();
      // 关键操作前先清掉积压的旧播报，让反馈立即响起
      speaker.clearPending();
      speaker.speak('已清空');
    } else if (key === '⌫') {
      speaker.clearPending();
      const deleted: boolean = this.deleteLast();
      if (deleted) {
        speaker.speak('已删除');
      } else {
        speaker.speak(this.tipText);
      }
    } else if (key === '=' || key === '确认') {
      speaker.clearPending();
      const calculated: boolean = this.calculate();
      if (calculated) {
        const spokenResult: string = resultToSpeech(this.resultText);
        if (spokenResult === '数字过大') {
          speaker.speak('计算完成，结果数字过大，请查看屏幕');
        } else {
          speaker.speak(`计算完成，结果是${spokenResult}`);
        }
      } else {
        speaker.speak(this.tipText);
      }
    } else if (key === '语音') {
      speaker.clearPending();
      this.startVoiceInput();
    } else {
      const accepted: boolean = this.appendInput(key);
      if (accepted) {
        speaker.speak(keyToSpeech(key));
      } else {
        speaker.speak(this.tipText);
      }
    }
  }

  private appendInput(value: string): boolean {
    if (this.justCalculated && !this.isArithmeticOperator(value)) {
      this.inputText = '';
      this.resultText = '0';
    }
    this.justCalculated = false;
    this.isListening = false;

    if (this.inputText.length >= 24) {
      this.tipText = '表达式过长，请先计算或清空';
      return false;
    }

    if (this.isArithmeticOperator(value)) {
      if (this.inputText === '') {
        this.tipText = '请先输入数字';
        return false;
      }

      const lastCharacter: string = this.inputText[this.inputText.length - 1];
      if (this.isArithmeticOperator(lastCharacter)) {
        this.inputText = this.inputText.slice(0, -1) + value;
      } else {
        this.inputText += value;
      }
    } else if (value === '.') {
      const currentNumber: string = this.getCurrentNumber();
      if (currentNumber.includes('.')) {
        this.tipText = '一个数字只能有一个小数点';
        return false;
      }
      this.inputText += currentNumber === '' ? '0.' : '.';
    } else {
      this.inputText += value;
    }

    this.tipText = `当前输入：${this.inputText}`;
    return true;
  }

  private clearAll(): void {
    this.inputText = '';
    this.resultText = '0';
    this.tipText = '已清空，请重新输入';
    this.isListening = false;
    this.justCalculated = false;
  }

  private deleteLast(): boolean {
    if (this.inputText.length > 0) {
      this.inputText = this.inputText.slice(0, -1);
      this.tipText = '已删除最后一位';
      this.resultText = '0';
      this.isListening = false;
      this.justCalculated = false;
      return true;
    } else {
      this.tipText = '当前没有可删除的内容';
      return false;
    }
  }

  private calculate(): boolean {
    if (this.inputText === '') {
      this.tipText = '请先输入表达式';
      this.isListening = false;
      return false;
    }

    const lastCharacter: string = this.inputText[this.inputText.length - 1];
    if (this.isArithmeticOperator(lastCharacter)) {
      this.tipText = '表达式不能以运算符结尾';
      this.isListening = false;
      return false;
    }

    const calculation: CalculationResult = this.evaluateExpression(this.inputText);
    if (calculation.success) {
      this.resultText = this.formatResult(calculation.value);
      this.tipText = '计算完成';
      this.justCalculated = true;
      this.isListening = false;
      return true;
    } else {
      this.resultText = '错误';
      this.tipText = calculation.message;
      this.justCalculated = false;
      this.isListening = false;
      return false;
    }
  }

  private startVoiceInput(): void {
    this.isListening = true;
    this.tipText = '语音识别尚未接入，点击按键可收听语音播报';
    TtsSpeaker.getInstance().speak('语音识别功能尚未接入');
  }

  // 使用双栈解析四则运算，避免使用 eval 执行不可信字符串。
  private evaluateExpression(expression: string): CalculationResult {
    const numbers: number[] = [];
    const operators: string[] = [];
    let numberBuffer: string = '';

    for (let index: number = 0; index < expression.length; index++) {
      const character: string = expression[index];
      if ((character >= '0' && character <= '9') || character === '.') {
        numberBuffer += character;
        continue;
      }

      if (!this.isArithmeticOperator(character) || numberBuffer === '') {
        return new CalculationResult(false, 0, '表达式格式不正确');
      }

      numbers.push(Number(numberBuffer));
      numberBuffer = '';
      while (operators.length > 0 &&
        this.getPriority(operators[operators.length - 1]) >= this.getPriority(character)) {
        if (!this.applyTopOperation(numbers, operators)) {
          return new CalculationResult(false, 0, '表达式无效或除数不能为 0');
        }
      }
      operators.push(character);
    }

    if (numberBuffer === '') {
      return new CalculationResult(false, 0, '表达式格式不正确');
    }
    numbers.push(Number(numberBuffer));

    while (operators.length > 0) {
      if (!this.applyTopOperation(numbers, operators)) {
        return new CalculationResult(false, 0, '表达式无效或除数不能为 0');
      }
    }

    if (numbers.length !== 1 || !Number.isFinite(numbers[0])) {
      return new CalculationResult(false, 0, '计算结果超出有效范围');
    }
    return new CalculationResult(true, numbers[0], '');
  }

  private applyTopOperation(numbers: number[], operators: string[]): boolean {
    if (numbers.length < 2 || operators.length === 0) {
      return false;
    }

    const right: number = numbers[numbers.length - 1];
    numbers.pop();
    const left: number = numbers[numbers.length - 1];
    numbers.pop();
    const operator: string = operators[operators.length - 1];
    operators.pop();
    let value: number = 0;

    if (operator === '+') {
      value = left + right;
    } else if (operator === '−') {
      value = left - right;
    } else if (operator === '×') {
      value = left * right;
    } else if (operator === '÷') {
      if (right === 0) {
        return false;
      }
      value = left / right;
    } else {
      return false;
    }

    numbers.push(value);
    return true;
  }

  private getCurrentNumber(): string {
    let startIndex: number = 0;
    for (let index: number = this.inputText.length - 1; index >= 0; index--) {
      if (this.isArithmeticOperator(this.inputText[index])) {
        startIndex = index + 1;
        break;
      }
    }
    return this.inputText.slice(startIndex);
  }

  private getPriority(operator: string): number {
    return operator === '×' || operator === '÷' ? 2 : 1;
  }

  private isArithmeticOperator(key: string): boolean {
    return ['+', '−', '×', '÷'].includes(key);
  }

  private isOperator(key: string): boolean {
    return ['C', '⌫', '+', '−', '×', '÷', '=', '确认', '语音'].includes(key);
  }

  private formatResult(value: number): string {
    const roundedValue: number = Math.round(value * 100000000) / 100000000;
    return roundedValue.toString();
  }
}
