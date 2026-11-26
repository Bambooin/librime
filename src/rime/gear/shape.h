//
// Copyright RIME Developers
// Distributed under the BSD License
//
// 2013-07-02 GONG Chen <chen.sst@gmail.com>
//

#ifndef RIME_SHAPE_H_
#define RIME_SHAPE_H_

#include <rime/formatter.h>
#include <rime/processor.h>

namespace rime {

class ShapeFormatter : public Formatter {
 public:
  ShapeFormatter(const Ticket& ticket) : Formatter(ticket) {}
  void Format(string* text) override;
};

class ShapeProcessor : public Processor {
 public:
  ShapeProcessor(const Ticket& ticket)
      : Processor(ticket), formatter_(ticket) {}
  ProcessResult ProcessKeyEvent(const KeyEvent& key_event) override;

 private:
  ShapeFormatter formatter_;
};

}  // namespace rime

#endif  // RIME_FORMATTER_H_
