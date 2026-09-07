import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'TtsSpeaker';
const MAX_QUEUE_SIZE: number = 30;

/**
 * 语音播报管理器。
 *
 * 封装系统 CoreSpeechKit 的文本转语音（TTS）能力：
 * - 使用离线中文语音，不需要麦克风权限，也不需要联网；
 * - 播报内容进入队列后串行朗读，快速连续点击时不会多条语音重叠；
 * - 引擎初始化是异步的，初始化完成前提交的文本会自动排队等待。
 */
export class TtsSpeaker {
  private static instance: TtsSpeaker | null = null;
  private engine: textToSpeech.TextToSpeechEngine | null = null;
  private speakQueue: string[] = [];
  private isSpeaking: boolean = false;
  private requestIndex: number = 0;

  private constructor() {
  }

  static getInstance(): TtsSpeaker {
    if (TtsSpeaker.instance === null) {
      TtsSpeaker.instance = new TtsSpeaker();
    }
    return TtsSpeaker.instance;
  }

  /**
   * 创建并初始化 TTS 引擎，页面加载时调用一次。
   *
   * @returns true 表示初始化成功，false 表示当前设备不支持或初始化失败。
   */
  init(): Promise<boolean> {
    if (this.engine !== null) {
      return Promise.resolve(true);
    }

    // person 0 为系统默认离线中文女声，兼容性最好；
    // online 1 表示离线合成，不需要联网。
    const extraParams: Record<string, Object> = {
      'style': 'interaction-broadcast',
      'locate': 'CN'
    };
    const createParams: textToSpeech.CreateEngineParams = {
      language: 'zh-CN',
      person: 0,
      online: 1,
      extraParams: extraParams
    };

    return textToSpeech.createEngine(createParams).then((engine: textToSpeech.TextToSpeechEngine) => {
      this.engine = engine;
      this.engine.setListener(this.createListener());
      hilog.info(DOMAIN, TAG, 'TTS engine created');
      // 初始化期间积压的文本，此时可以开始朗读
      this.pump();
      return true;
    }).catch((error: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'create TTS engine failed, code=%{public}d, message=%{public}s',
        error.code, error.message);
      return false;
    });
  }

  /**
   * 提交一段需要朗读的文本。引擎未就绪时先排队，就绪后自动播放。
   */
  speak(text: string): void {
    const content: string = text.trim();
    if (content === '') {
      return;
    }
    if (this.speakQueue.length >= MAX_QUEUE_SIZE) {
      this.speakQueue.shift();
    }
    this.speakQueue.push(content);
    this.pump();
  }

  /**
   * 丢弃尚未开始朗读的积压文本（正在朗读的这条不会被中断）。
   * 清空、退格、计算等关键操作前调用，避免旧按键内容滞后播报。
   */
  clearPending(): void {
    this.speakQueue = [];
  }

  /**
   * 释放 TTS 引擎资源，页面销毁时调用。
   */
  shutdown(): void {
    this.speakQueue = [];
    this.isSpeaking = false;
    if (this.engine === null) {
      return;
    }
    try {
      this.engine.stop();
      this.engine.shutdown();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'shutdown engine failed, error=%{public}s', JSON.stringify(error));
    }
    this.engine = null;
  }

  private createListener(): textToSpeech.SpeakListener {
    return {
      onStart: (requestId: string, response: textToSpeech.StartResponse): void => {
        hilog.info(DOMAIN, TAG, 'speak start, requestId=%{public}s', requestId);
      },
      onComplete: (requestId: string, response: textToSpeech.CompleteResponse): void => {
        this.onPlayFinished(requestId);
      },
      onStop: (requestId: string, response: textToSpeech.StopResponse): void => {
        this.onPlayFinished(requestId);
      },
      onError: (requestId: string, errorCode: number, errorMessage: string): void => {
        hilog.error(DOMAIN, TAG, 'speak error, requestId=%{public}s, code=%{public}d, message=%{public}s',
          requestId, errorCode, errorMessage);
        this.onPlayFinished(requestId);
      }
    };
  }

  private onPlayFinished(requestId: string): void {
    hilog.info(DOMAIN, TAG, 'speak finished, requestId=%{public}s', requestId);
    this.isSpeaking = false;
    this.pump();
  }

  private pump(): void {
    if (this.engine === null || this.isSpeaking) {
      return;
    }
    const content: string | undefined = this.speakQueue.shift();
    if (content === undefined) {
      return;
    }

    this.isSpeaking = true;
    this.requestIndex++;
    const requestId: string = `calculator_tts_${this.requestIndex}`;
    try {
      this.engine.speak(content, { requestId: requestId });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'engine speak failed, error=%{public}s', JSON.stringify(error));
      this.isSpeaking = false;
      this.pump();
    }
  }
}

const DIGIT_TEXT: string[] = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
const SMALL_UNIT_TEXT: string[] = ['', '十', '百', '千'];
const SECTION_UNIT_TEXT: string[] = ['', '万', '亿'];

function isDigitChar(character: string): boolean {
  return character.length === 1 && character >= '0' && character <= '9';
}

function digitToText(digitChar: string): string {
  return DIGIT_TEXT[digitChar.charCodeAt(0) - 48];
}

/**
 * 把单个按键转换成更适合中文朗读的文本。
 */
export function keyToSpeech(key: string): string {
  if (isDigitChar(key)) {
    return digitToText(key);
  }
  switch (key) {
    case '+':
      return '加';
    case '−':
      return '减';
    case '×':
      return '乘';
    case '÷':
      return '除';
    case '.':
      return '点';
    case 'C':
      return '清空';
    case '⌫':
      return '删除';
    case '=':
      return '等于';
    case '确认':
      return '等于';
    default:
      return key;
  }
}

function isAllDigits(text: string): boolean {
  for (let index: number = 0; index < text.length; index++) {
    if (!isDigitChar(text.charAt(index))) {
      return false;
    }
  }
  return true;
}

// 把一个 1~4 位的分段转成中文读法（只处理段内零，不处理跨段零；全零段返回空串）
function groupToText(group: string): string {
  const length: number = group.length;
  if (length === 1) {
    return digitToText(group);
  }
  // 两位且以 1 开头时读“十/十一”，例如 10 万、15 亿
  if (length === 2 && group.charAt(0) === '1') {
    const secondDigit: string = group.charAt(1);
    return secondDigit === '0' ? '十' : '十' + digitToText(secondDigit);
  }

  let result: string = '';
  let needZero: boolean = false;
  for (let index: number = 0; index < length; index++) {
    const digitChar: string = group.charAt(index);
    const position: number = length - 1 - index;
    if (digitChar === '0') {
      // 段内中间出现的零只补一次；末尾零不读
      if (result !== '' && position > 0) {
        needZero = true;
      }
    } else {
      if (needZero) {
        result += '零';
        needZero = false;
      }
      result += digitToText(digitChar) + SMALL_UNIT_TEXT[position];
    }
  }
  return result;
}

/**
 * 把整数部分的数字串转成中文读法，最大支持到 9999 亿。
 */
function integerToText(rawIntText: string): string {
  let intText: string = rawIntText;
  while (intText.length > 1 && intText.charAt(0) === '0') {
    intText = intText.substring(1);
  }
  if (intText === '') {
    return '零';
  }
  if (intText.length > 12) {
    return '数字过大';
  }

  // 从右往左每 4 位切成一段，例如 100010000 -> ['1', '0001', '0000']
  const groups: string[] = [];
  let endIndex: number = intText.length;
  while (endIndex > 0) {
    const startIndex: number = endIndex - 4 >= 0 ? endIndex - 4 : 0;
    groups.unshift(intText.substring(startIndex, endIndex));
    endIndex = startIndex;
  }

  let result: string = '';
  let pendingEmptyGroup: boolean = false;
  for (let index: number = 0; index < groups.length; index++) {
    const group: string = groups[index];
    const groupText: string = groupToText(group);
    const unitText: string = SECTION_UNIT_TEXT[groups.length - 1 - index];
    if (groupText === '') {
      // 整段都是 0：先记录，等后面遇到非零段时补一个“零”
      if (result !== '') {
        pendingEmptyGroup = true;
      }
    } else {
      // 非最高段以 0 开头（段值小于 1000）时也要在段前补“零”，例如 一亿零一万
      const needLeadingZero: boolean = pendingEmptyGroup ||
        (result !== '' && group.charAt(0) === '0');
      if (needLeadingZero) {
        result += '零';
      }
      pendingEmptyGroup = false;
      result += groupText + unitText;
    }
  }
  return result === '' ? '零' : result;
}

/**
 * 把计算结果（阿拉伯数字文本）转成适合中文朗读的文本。
 * 超出整数转换范围（超过 9999 亿）或带科学计数法时返回“数字过大”，提示用户看屏幕。
 */
export function resultToSpeech(resultText: string): string {
  if (resultText === '0' || resultText === '错误') {
    return resultText === '0' ? '零' : '错误';
  }

  let text: string = resultText;
  let negative: boolean = false;
  if (text.startsWith('-')) {
    negative = true;
    text = text.substring(1);
  }

  const dotIndex: number = text.indexOf('.');
  const intPart: string = dotIndex === -1 ? text : text.substring(0, dotIndex);
  const fractionPart: string = dotIndex === -1 ? '' : text.substring(dotIndex + 1);
  if (intPart === '' || !isAllDigits(intPart) || !isAllDigits(fractionPart)) {
    return '数字过大';
  }

  let spoken: string = integerToText(intPart);
  if (spoken === '数字过大') {
    return spoken;
  }
  if (fractionPart !== '') {
    spoken += '点';
    for (let index: number = 0; index < fractionPart.length; index++) {
      spoken += digitToText(fractionPart.charAt(index));
    }
  }
  return negative ? '负' + spoken : spoken;
}
