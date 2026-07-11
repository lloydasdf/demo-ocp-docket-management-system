'use client';

import { useState } from 'react';

import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';

type LookupOption = { id: number; display_label: string };

type CreatableLookupSelectProps<TOption extends LookupOption> = {
  value: string;
  onValueChange: (value: string) => void;
  options: TOption[];
  placeholder: string;
  addLabel: string;
  dialogTitle: string;
  labelField: string;
  disabled?: boolean;
  className?: string;
  noneOption?: { value: string; label: string };
  renderOption?: (option: TOption) => string;
  onCreate: (label: string) => Promise<{ id: number; error?: string | null }>;
};

const addValue = '__add_lookup__';

export function CreatableLookupSelect<TOption extends LookupOption>({
  value,
  onValueChange,
  options,
  placeholder,
  addLabel,
  dialogTitle,
  labelField,
  disabled,
  className,
  noneOption,
  renderOption = (option) => option.display_label,
  onCreate,
}: CreatableLookupSelectProps<TOption>) {
  const [isOpen, setIsOpen] = useState(false);
  const [label, setLabel] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  const handleValueChange = (nextValue: string) => {
    if (nextValue === addValue) {
      setLabel('');
      setError(null);
      setIsOpen(true);
      return;
    }

    onValueChange(nextValue);
  };

  const handleSave = async () => {
    const nextLabel = label.trim();
    if (!nextLabel) return;
    setError(null);
    setIsSaving(true);
    const result = await onCreate(nextLabel);
    setIsSaving(false);

    if (result.error) {
      if (result.id) onValueChange(String(result.id));
      setError(result.error);
      return;
    }

    onValueChange(String(result.id));
    setIsOpen(false);
    setLabel('');
  };

  return (
    <>
      <Select value={value} onValueChange={handleValueChange} disabled={disabled}>
        <SelectTrigger className={className}><SelectValue placeholder={placeholder} /></SelectTrigger>
        <SelectContent>
          {noneOption ? <SelectItem value={noneOption.value}>{noneOption.label}</SelectItem> : null}
          {options.map((option) => <SelectItem key={option.id} value={option.id.toString()}>{renderOption(option)}</SelectItem>)}
          <SelectItem value={addValue}>+ {addLabel}</SelectItem>
        </SelectContent>
      </Select>

      <Dialog open={isOpen} onOpenChange={setIsOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{dialogTitle}</DialogTitle>
            <DialogDescription>Add a new active lookup option. Codes are generated automatically and duplicates are validated case-insensitively.</DialogDescription>
          </DialogHeader>
          <div className="space-y-2">
            <Label htmlFor="creatable-lookup-label">{labelField}</Label>
            <Input id="creatable-lookup-label" value={label} onChange={(event) => setLabel(event.target.value)} />
            {error ? <p className="text-sm text-destructive">{error}</p> : null}
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => setIsOpen(false)}>Cancel</Button>
            <Button type="button" onClick={handleSave} disabled={isSaving || !label.trim()}>{isSaving ? 'Saving...' : 'Save'}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
