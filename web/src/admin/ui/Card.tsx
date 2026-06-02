import type { ReactNode } from "react";
import { Icon, type IconName } from "./Icon";
import "./Card.css";

/**
 * Card — the bordered section block used across the Config view. Mirrors the
 * merged mockup's `.card`: an icon chip + uppercase title + optional subtitle
 * in the head, content in the body. Sections compose these inside a
 * `.mbt-card-grid` to get the dashboard card layout.
 *
 * Card chrome is intentionally quiet: neutral icon (never the accent), one
 * surface step above the section. `hero` lifts a single focal card.
 */

export interface CardProps {
  icon?: IconName;
  title: string;
  subtitle?: string;
  /** Right-aligned header action (e.g. an Add button). */
  action?: ReactNode;
  /** Lifts this card as the focal element (Interaction Zone). */
  hero?: boolean;
  className?: string;
  children: ReactNode;
}

export function Card({
  icon,
  title,
  subtitle,
  action,
  hero,
  className,
  children,
}: CardProps) {
  return (
    <section
      className={`mbt-card${hero ? " mbt-card--hero" : ""}${
        className ? ` ${className}` : ""
      }`}
    >
      <header className="mbt-card__head">
        {icon && (
          <span className="mbt-card__ic">
            <Icon name={icon} size={15} />
          </span>
        )}
        <div className="mbt-card__head-tx">
          <h4 className="mbt-card__title">{title}</h4>
          {subtitle && <p className="mbt-card__sub">{subtitle}</p>}
        </div>
        {action && <div className="mbt-card__action">{action}</div>}
      </header>
      <div className="mbt-card__body">{children}</div>
    </section>
  );
}

export default Card;
