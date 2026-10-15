/// Verified support contacts shown when the on-device safety screening triggers
/// (SRS FR-19). Edit only here. Add a campus-support contact once it is verified.
class Helpline {
  const Helpline(this.name, this.number);

  final String name;
  final String number;
}

const List<Helpline> kHelplines = [
  Helpline('Punjab Institute of Mental Health, Lahore', '+92 42 99203776'),
];