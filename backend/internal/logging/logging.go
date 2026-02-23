package logging

import (
	"os"
	"sync"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
	"gopkg.in/natefinch/lumberjack.v2"
	"routeguard/internal/config"
)

// lumberjackSync - обёртка для добавления Sync метода
type lumberjackSync struct {
	*lumberjack.Logger
	mu sync.Mutex
}

func (l *lumberjackSync) Sync() error {
	l.mu.Lock()
	defer l.mu.Unlock()
	return nil
}

func New(cfg config.LoggingConfig) (*zap.Logger, error) {
	level, err := zapcore.ParseLevel(cfg.Level)
	if err != nil {
		level = zapcore.InfoLevel
	}

	atom := zap.NewAtomicLevelAt(level)

	// Console output
	consoleEncoder := zapcore.NewConsoleEncoder(zap.NewDevelopmentEncoderConfig())
	consoleCore := zapcore.NewCore(consoleEncoder, zapcore.Lock(os.Stdout), atom)

	var cores []zapcore.Core
	cores = append(cores, consoleCore)

	// File output
	if cfg.File != "" {
		fileWriter := &lumberjackSync{
			Logger: &lumberjack.Logger{
				Filename:   cfg.File,
				MaxSize:    cfg.MaxSizeMB,
				MaxBackups: cfg.MaxBackups,
				LocalTime:  true,
				Compress:   true,
			},
		}
		fileEncoder := zapcore.NewJSONEncoder(zap.NewProductionEncoderConfig())
		fileCore := zapcore.NewCore(fileEncoder, zapcore.Lock(fileWriter), atom)
		cores = append(cores, fileCore)
	}

	combinedCore := zapcore.NewTee(cores...)
	logger := zap.New(combinedCore, zap.AddCaller(), zap.AddCallerSkip(1))

	return logger, nil
}
