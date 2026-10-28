package alert

import (
	"crypto/tls"
	"fmt"
	"net"
	"net/mail"
	"net/smtp"
	"strconv"
	"strings"
	"time"

	"disk-usage-alert/internal/config"
)

type EmailSender struct {
	host     string
	port     string
	username string
	password string
	from     string
	to       string
}

func NewEmailSender(cfg config.Config) *EmailSender {
	return &EmailSender{
		host:     cfg.SMTPHost,
		port:     cfg.SMTPPort,
		username: cfg.SMTPUsername,
		password: cfg.SMTPPassword,
		from:     cfg.EmailFrom,
		to:       cfg.EmailTo,
	}
}

func (s *EmailSender) Send(subject, body string) error {
	from, err := mail.ParseAddress(s.from)
	if err != nil || from.Address != s.from {
		return fmt.Errorf("invalid EMAIL_FROM address")
	}

	to, err := mail.ParseAddress(s.to)
	if err != nil || to.Address != s.to {
		return fmt.Errorf("invalid EMAIL_TO address")
	}

	if strings.ContainsAny(subject, "\r\n") {
		return fmt.Errorf("invalid email subject")
	}

	port, err := strconv.Atoi(s.port)
	if err != nil {
		return fmt.Errorf("invalid SMTP port: %w", err)
	}

	address := net.JoinHostPort(s.host, s.port)
	dialer := &net.Dialer{Timeout: 15 * time.Second}

	var conn net.Conn

	if port == 465 {
		conn, err = tls.DialWithDialer(
			dialer,
			"tcp",
			address,
			&tls.Config{
				ServerName: s.host,
				MinVersion: tls.VersionTLS12,
			},
		)
	} else {
		conn, err = dialer.Dial("tcp", address)
	}

	if err != nil {
		return fmt.Errorf("connect to SMTP server: %w", err)
	}
	defer conn.Close()

	if err := conn.SetDeadline(time.Now().Add(30 * time.Second)); err != nil {
		return fmt.Errorf("set SMTP deadline: %w", err)
	}

	client, err := smtp.NewClient(conn, s.host)
	if err != nil {
		return fmt.Errorf("initialize SMTP client: %w", err)
	}
	defer client.Close()

	if port != 465 {
		if ok, _ := client.Extension("STARTTLS"); !ok {
			return fmt.Errorf("SMTP server does not support STARTTLS")
		}

		if err := client.StartTLS(&tls.Config{
			ServerName: s.host,
			MinVersion: tls.VersionTLS12,
		}); err != nil {
			return fmt.Errorf("start TLS: %w", err)
		}
	}

	auth := smtp.PlainAuth("", s.username, s.password, s.host)
	if err := client.Auth(auth); err != nil {
		return fmt.Errorf("SMTP authentication: %w", err)
	}

	if err := client.Mail(from.Address); err != nil {
		return fmt.Errorf("set sender: %w", err)
	}

	if err := client.Rcpt(to.Address); err != nil {
		return fmt.Errorf("set recipient: %w", err)
	}

	writer, err := client.Data()
	if err != nil {
		return fmt.Errorf("start email body: %w", err)
	}

	message := fmt.Sprintf(
		"From: %s\r\nTo: %s\r\nSubject: %s\r\n"+
			"MIME-Version: 1.0\r\n"+
			"Content-Type: text/plain; charset=UTF-8\r\n"+
			"\r\n%s\r\n",
		from.String(),
		to.String(),
		subject,
		body,
	)

	if _, err := fmt.Fprint(writer, message); err != nil {
		_ = writer.Close()
		return fmt.Errorf("write email body: %w", err)
	}

	if err := writer.Close(); err != nil {
		return fmt.Errorf("send email body: %w", err)
	}

	if err := client.Quit(); err != nil {
		return fmt.Errorf("finish SMTP session: %w", err)
	}

	return nil
}
