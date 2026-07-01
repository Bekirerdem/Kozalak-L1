/**
 * @clack/prompts ince sarmalayıcısı.
 *
 * intro/outro/cancel burada sabitlenir (banner metni, exit kodu); diğer
 * prompt fonksiyonları (select/text/password/confirm/isCancel) doğrudan
 * @clack/prompts'tan re-export edilir. Sonraki task'lar bu modülden import
 * eder, doğrudan @clack/prompts'a bağımlı olmaz.
 */
import {
  intro as clackIntro,
  outro as clackOutro,
  cancel as clackCancel,
} from "@clack/prompts";

/** CLI banner'ını yazdırır. */
export const intro = (): void => {
  clackIntro("create-kozalak-l1");
};

/** Kapanış mesajını yazdırır. */
export const outro = (msg: string): void => {
  clackOutro(msg);
};

/** İptal mesajını yazdırır ve süreci hata koduyla sonlandırır. */
export function cancel(msg: string): never {
  clackCancel(msg);
  process.exit(1);
}

export { select, text, password, confirm, isCancel, note, log } from "@clack/prompts";
